#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

cleanup() {
  # No further need for the trap
  trap - EXIT INT TERM

  # Export the created pool, if it exists
  [ -n "${zpool_name}" ] || return
  zpool list -H -o name "${zpool_name}" >/dev/null 2>&1 || return
  zpool export "${zpool_name}"
}

error() {
  echo "ERROR: $*" >&2
}

usage() {
  cat <<-EOF
	USAGE: $0 [OPTIONS] <pool>
	
	  Create a ZFS pool with the given name
	
	OPTIONS
	-h
	   Display this message and exit

	-c <compat>
	   Use the specified ZFS compatibility option
           (This can also set as ZPOOL_COMPAT in the environment)
	
	-d <device>
	   Create the pool on the specified device
	
	-e <keyfile>
	   Encrypt the pool, writing the key to the specified file
           (This can also be set as ENCRYPT_KEYFILE in the environment)
	EOF
}

# Find exactly one disk or loopback device
find_device() {
  zdev=
  while read -r dev typ _; do
    [ "${typ}" = "loop" ] || [ "${typ}" = "disk" ] || continue

    if [ -n "${zdev}" ]; then
      error "pool device is ambiguous"
      return 1
    fi

    zdev="${dev}"
  done <<< "$(lsblk -n -o name,type --raw -p)"

  echo "${zdev}"
}

zpool_device=

while getopts "hc:d:e:" opt; do
  case "${opt}" in
    c)
      ZPOOL_COMPAT="${OPTARG}"
      ;;
    d)
      zpool_device="${OPTARG}"
      ;;
    e)
      ENCRYPT_KEYFILE="${OPTARG}"
      ;;
    h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1))
zpool_name="${1?ERROR: a pool name is required}"

if [ -z "${zpool_device}" ] && ! zpool_device="$(find_device)"; then
  error "failed to find device for pool"
  exit 1
fi

if [ ! -b "${zpool_device}" ]; then
  error "path '${zpool_device}' is not a block special device"
  exit 1
fi

# When a new pool should be encrypted, it needs a key
if [ -n "${ENCRYPT_KEYFILE}" ]; then
  if ! ENCRYPT_KEYFILE="$(realpath "${ENCRYPT_KEYFILE}" 2>/dev/null)"; then
    error "failed to canonicalize path to keyfile"
    exit 1
  fi

  echo "zfsbootmenu" > "${ENCRYPT_KEYFILE}"
fi

# Partition the disk
echo 'label: gpt' | sfdisk "${zpool_device}"

# Default pool options
pool_opts=(
  "-O" "compression=lz4"
  "-O" "acltype=posixacl"
  "-O" "xattr=sa"
  "-O" "relatime=on"
  "-o" "autotrim=on"
  "-o" "cachefile=none"
)

# Enable encryption, if desired
if [ -r "${ENCRYPT_KEYFILE}" ]; then
    pool_opts+=(
      "-O" "encryption=aes-256-gcm"
      "-O" "keyformat=passphrase"
      "-O" "keylocation=file://${ENCRYPT_KEYFILE}"
    )
fi

# Set any desired pool compatibility level
if [ -n "${ZPOOL_COMPAT}" ]; then
  pool_opts+=( "-o" "compatibility=${ZPOOL_COMPAT}" )
fi

# Make sure that the pool is exported on error
trap cleanup EXIT INT TERM

# Create the pool
if ! zpool create -f -m none "${pool_opts[@]}" "${zpool_name}" "${zpool_device}"; then
  error "unable to create pool '${zpool_name}' on device '${zpool_device}'"
  exit 1
fi

# Fix the key location for running inside the environment
if [ -r "${ENCRYPT_KEYFILE}" ]; then
  zfs set "keylocation=file:///etc/zfs/${ENCRYPT_KEYFILE##*/}" "${zpool_name}"
fi

# Create a dummy snapshot and the boot-environment parent
zfs snapshot -r "${zpool_name}@barepool"
zfs create -o mountpoint=none "${zpool_name}/ROOT"

# Export the pool
zpool export "${zpool_name}"
unset zpool_name

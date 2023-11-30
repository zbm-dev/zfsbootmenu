#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

error() {
  echo "ERROR: $*" >&2
}

cleanup() {
  trap - EXIT INT TERM

  if [ -n "${LOOP_DEV}" ]; then
    echo "Deleting loopback device '${LOOP_DEV}'"
    kpartx -d "${LOOP_DEV}"
    losetup -d "${LOOP_DEV}"
    unset LOOP_DEV
  fi

  exit
}

usage() {
  cat <<-EOF
	USAGE: $0 [OPTIONS] <distro> <pool> <testdir>
	
	  Set up a distribution on the given ZFS pool, on bare metal
	
	OPTIONS
	-h
	   Display this message and exit
	
	-c <compat>
	   Use the specified ZFS compatibility option
	
	-e <keyfile>
	   If the pool is (to be) encrypted, unlock with the given key file
	
	-E <environ>
	   Add a variable to the install environment
	   (The argument environ should take the form 'KEY=VALUE')
	
	-i <imgfile>
	   Specify the path to the disk image file
	   (Default: \${testdir}/\${pool}-pool.img)
	
	-x
	   Assume the pool already exists
	EOF
}

encrypt_keyfile=
existing_pool=
zpool_compat=
disk_image=

environs=( )

while getopts "hc:e:E:i:x" opt; do
  case "${opt}" in
    e)
      encrypt_keyfile="${OPTARG}"
      ;;
    E)
      environs+=( "${OPTARG}" )
      ;;
    c)
      zpool_compat="${OPTARG}"
      ;;
    i)
      disk_image="${OPTARG}"
      ;;
    x)
      existing_pool="yes"
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

shift "$((OPTIND - 1))"

distro="${1?a distribution name is required}"
zpool_name="${2?a pool name is required}"

testdir="${3}"
if [ ! -d "${testdir}" ]; then
  error "test directory must be specified and must exist"
  exit 1
fi

[ -n "${disk_image}" ] || disk_image="${testdir}/${zpool_name}-pool.img"

if [ ! -r "${disk_image}" ]; then
  error "disk image does not exist or is not accessible"
  exit 1
fi

INSTALL_SCRIPT="./helpers/install-${distro}.sh"
if [ ! -x "${INSTALL_SCRIPT}" ]; then
  error "install script '${INSTALL_SCRIPT}' missing or not executable"
  exit 1
fi

CHROOT_SCRIPT="./helpers/chroot-${distro}.sh"
if [ ! -x "${CHROOT_SCRIPT}" ]; then
  error "chroot script '${CHROOT_SCRIPT}' missing or not executable"
  exit 1
fi

export LOOP_DEV=""

# Perform all necessary cleanup for this script
trap cleanup EXIT INT TERM

# Attach the loopback device and update partition mappings
if ! LOOP_DEV="$( losetup -f --show "${disk_image}" )"; then
  error "unable to attach loopback device to '${disk_image}'"
  exit 1
else
  export LOOP_DEV
fi

kpartx -u "${LOOP_DEV}"

encrypt_opts=( )
[ -n "${encrypt_keyfile}" ] && encrypt_opts=( -e "${encrypt_keyfile}" )

compat_opts=( )
[ -n "${zpool_compat}" ] && compat_opts=( -c "${zpool_compat}" )

if [ "${existing_pool,,}" != "yes" ]; then
  if ! ./helpers/pool-create.sh -d "${LOOP_DEV}" \
        "${encrypt_opts[@]}" "${compat_opts[@]}" "${zpool_name}"; then
    error "failed to create pool '${zpool_name}' on '${disk_image}'"
    exit 1
  fi
fi

exec env "${environs[@]}" ./helpers/pool-setup.sh \
  "${encrypt_opts[@]}" "${distro}" "${zpool_name}" "${testdir}"

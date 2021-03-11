#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

cleanup() {
  if [ -n "${CHROOT_MNT}" ]; then
    echo "Cleaning up chroot mount '${CHROOT_MNT}'"
    mountpoint -q "${CHROOT_MNT}" && umount -R "${CHROOT_MNT}"
    [ -d "${CHROOT_MNT}" ] && rmdir "${CHROOT_MNT}"
    unset CHROOT_MNT
  fi

  if [ -n "${ZBM_POOL}" ]; then
    echo "Exporting pool '${ZBM_POOL}'"
    zpool export "${ZBM_POOL}"
    unset ZBM_POOL
  fi

  if [ -n "${LOOP_DEV}" ]; then
    echo "Deleting loopback device '${LOOP_DEV}'"
    losetup -d "${LOOP_DEV}"
    unset LOOP_DEV
  fi

  exit
}

TESTDIR="${1?Usage: $0 <testdir> <size> <distro> <pool name>}"
SIZE="${2?Usage: $0 <testdir> <size> <distro> <pool name>}"
DISTRO="${3?Usage: $0 <testdir> <size> <distro> <pool name>}"
zpool_name="${4?Usage: $0 <testdir> <size> <distro> <pool name>}"

if [ -z "${TESTDIR}" ] || [ ! -d "${TESTDIR}" ]; then
  echo "ERROR: test directory must be specified and must exist"
  exit 1
fi

INSTALL_SCRIPT="./helpers/install-${DISTRO}.sh"
if [ ! -x "${INSTALL_SCRIPT}" ]; then
  echo "ERROR: install script '${INSTALL_SCRIPT}' missing or not executable"
  exit 1
fi

CHROOT_SCRIPT="./helpers/chroot-${DISTRO}.sh"
if [ ! -x "${CHROOT_SCRIPT}" ]; then
  echo "ERROR: chroot script '${CHROOT_SCRIPT}' missing or not executable"
  exit 1
fi

export ZBM_POOL=""
export LOOP_DEV=""

CHROOT_MNT="$( mktemp -d )" || exit 1
export CHROOT_MNT

# Perform all necessary cleanup for this script
trap cleanup EXIT INT TERM

ZBMIMG="${TESTDIR}/${zpool_name}-pool.img"

if [ -z "${EXISTING_POOL}" ]; then
  usergroup="$( stat -c %U . ):$( stat -c %G . )"

  qemu-img create "${ZBMIMG}" "${SIZE}"
  chown "${usergroup}" "${ZBMIMG}"

  # When a new pool should be encrypted, it needs a key
  if [ -n "${ENCRYPT}" ]; then
    echo "zfsbootmenu" > "${TESTDIR}/${zpool_name}.key"
    chown "${usergroup}" "${TESTDIR}/${zpool_name}.key"
  fi
elif [ ! -e "${ZBMIMG}" ]; then
  echo "ERROR: cannot use non-existent image ${ZBMIMG} as existing pool"
  exit 1
fi

if ENCRYPT_KEYFILE="$( realpath -e "${TESTDIR}/${zpool_name}.key" 2>/dev/null )"; then
  export ENCRYPT_KEYFILE
elif [ -n "${ENCRYPT}" ]; then
  echo "ERROR: unable to find real path to encryption key file"
  exit 1
fi

if ! LOOP_DEV="$( losetup -f --show "${ZBMIMG}" )"; then
  echo "ERROR: unable to attach loopback device"
  exit 1
else
  export LOOP_DEV
fi

if [ -z "${EXISTING_POOL}" ]; then
  kpartx -u "${LOOP_DEV}"

  echo 'label: gpt' | sfdisk "${LOOP_DEV}"

  ENCRYPT_OPTS=()
  if [ -r "${ENCRYPT_KEYFILE}" ]; then
    ENCRYPT_OPTS=( "-O" "encryption=aes-256-gcm" "-O" "keyformat=passphrase" )
    ENCRYPT_OPTS+=( "-O" "keylocation=file://${ENCRYPT_KEYFILE}" )
  fi

  LEGACY_OPTS=()
  if [ -n "${LEGACY_POOL}" ]; then
    legacy_features=( zstd_compress bookmark_written livelist log_spacemap )
    legacy_features+=( redacted_datasets redaction_bookmarks device_rebuild )
    for feature in "${legacy_features[@]}"; do
      LEGACY_OPTS+=( "-o" "feature@${feature}=disabled" )
    done
  fi

  if zpool create -f -m none \
        -O compression=lz4 \
        -O acltype=posixacl \
        -O xattr=sa \
        -O relatime=on \
        -o autotrim=on \
        -o cachefile=none \
        "${LEGACY_OPTS[@]}" \
        "${ENCRYPT_OPTS[@]}" \
        "${zpool_name}" "${LOOP_DEV}"; then
    export ZBM_POOL="${zpool_name}"
  else
    echo "ERROR: unable to create pool ${zpool_name}"
    exit 1
  fi

  if [ -r "${ENCRYPT_KEYFILE}" ]; then
    zfs set "keylocation=file:///etc/zfs/${ZBM_POOL}.key" "${ZBM_POOL}"
  fi

  zfs snapshot -r "${ZBM_POOL}@barepool"
  zfs create -o mountpoint=none "${ZBM_POOL}/ROOT"

  zpool export "${ZBM_POOL}"
  export ZBM_POOL=""
fi

if ! zpool import -o cachefile=none -R "${CHROOT_MNT}" "${zpool_name}"; then
  echo "ERROR: unable to import ZFS pool ${zpool_name}"
  exit 1
else
  export ZBM_POOL="${zpool_name}"
fi

ZBM_ROOT="${ZBM_POOL}/ROOT/${DISTRO}"
if zfs list -o name -H "${ZBM_ROOT}" >/dev/null 2>&1; then
  echo "ERROR: ZFS filesystem ${ZBM_ROOT} already exists"
  exit 1
fi

case "$( zfs get -H -o value encryptionroot "${ZBM_POOL}" 2>/dev/null )" in
  "-"|"")
    ;;
  *)
    if [ -r "${ENCRYPT_KEYFILE}" ]; then
      zfs load-key -L "file://${ENCRYPT_KEYFILE}" "${ZBM_POOL}"
    else
      zfs load-key -L prompt "${ZBM_POOL}"
      export ENCRYPT_KEYFILE=""
    fi
esac

zfs create -o mountpoint=/ -o canmount=noauto "${ZBM_ROOT}"
zfs snapshot -r "${ZBM_ROOT}@barebe"

zfs set org.zfsbootmenu:commandline="spl_hostid=$( hostid ) rw loglevel=4 console=tty1 console=ttyS0" "${ZBM_ROOT}"
zpool set bootfs="${ZBM_ROOT}" "${ZBM_POOL}"

if ! zfs mount "${ZBM_ROOT}"; then
  echo "ERROR: unable to mount ${ZBM_ROOT}"
  exit 1
fi

# Make sure the ZFS key exists in the BE
if [ -r "${ENCRYPT_KEYFILE}" ]; then
  mkdir -p "${CHROOT_MNT}/etc/zfs"
  cp "${ENCRYPT_KEYFILE}" "${CHROOT_MNT}/etc/zfs/"
fi

if ! "${INSTALL_SCRIPT}"; then
  echo "ERROR: install script '${INSTALL_SCRIPT}' failed"
  exit 1
fi

zfs snapshot -r "${ZBM_ROOT}@pre-chroot"

# Make sure the chroot script exists
mkdir -p "${CHROOT_MNT}/root"
cp "${CHROOT_SCRIPT}" "${CHROOT_MNT}/root/"

# Make sure special filesystems are mounted
mkdir -p "${CHROOT_MNT}"/{proc,sys,dev/pts}
mount -t proc proc "${CHROOT_MNT}/proc"
mount -t sysfs sys "${CHROOT_MNT}/sys"
mount -B /dev "${CHROOT_MNT}/dev" && mount --make-slave "${CHROOT_MNT}/dev"
mount -t devpts pts "${CHROOT_MNT}/dev/pts"

# Make sure the zpool information is cached
mkdir -p "${CHROOT_MNT}/etc/zfs"
zpool set cachefile="${CHROOT_MNT}/etc/zfs/zpool.cache" "${ZBM_POOL}"

# Pre-populate SSH keys, if available
if [ -d "./keys/etc/ssh" ]; then
  mkdir -p "${CHROOT_MNT}/etc"
  cp -R "./keys/etc/ssh" "${CHROOT_MNT}/etc/"
fi

# Pre-populate authorized keys, if available
if [ -r "./keys/authorized_keys" ]; then
  mkdir -p "${CHROOT_MNT}/root/.ssh"
  chmod 700 "${CHROOT_MNT}/root/.ssh"
  cp "./keys/authorized_keys" "${CHROOT_MNT}/root/.ssh/"
fi

# Launch the chroot script
if ! chroot "${CHROOT_MNT}" "/root/${CHROOT_SCRIPT##*/}"; then
  echo "ERROR: chroot script '${CHROOT_SCRIPT}' failed"
  exit 1
fi

zfs snapshot -r "${ZBM_ROOT}@full-setup"

touch "${CHROOT_MNT}/root/IN_THE_MATRIX"
zfs snapshot -r "${ZBM_ROOT}@minor-changes"

rm "${CHROOT_MNT}/root/IN_THE_MATRIX"
rm "${CHROOT_MNT}/root/${CHROOT_SCRIPT##*/}"

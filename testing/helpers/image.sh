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
ZBM_POOL="${3?Usage: $0 <testdir> <size> <distro> <pool name>}"

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

export ZBM_POOL
export LOOP_DEV=""

CHROOT_MNT="$( mktemp -d )" || exit 1
export CHROOT_MNT

# Perform all necessary cleanup for this script
trap cleanup EXIT INT TERM

ZBMIMG="${TESTDIR}/${ZBM_POOL}-pool.img"
qemu-img create "${ZBMIMG}" "${SIZE}"
chown "$( stat -c %U . ):$( stat -c %G . )" "${ZBMIMG}"

if ! LOOP_DEV="$( losetup -f --show "${ZBMIMG}" )"; then
  echo "ERORR: unable to attach loopback device"
  exit 1
else
  export LOOP_DEV
fi

kpartx -u "${LOOP_DEV}"

echo 'label: gpt' | sfdisk "${LOOP_DEV}"

ENCRYPT_OPTS=()
if [ -n "${ENCRYPT}" ]; then
  ENCRYPT_OPTS=( "-O" "encryption=aes-256-gcm" "-O" "keyformat=passphrase" )

  echo "zfsbootmenu" > "${TESTDIR}/${ZBM_POOL}.key"
  if [ ! -r "${TESTDIR}/${ZBM_POOL}.key" ]; then
    echo "ERROR: unable to read encryption keyfile"
    exit 1
  fi

  chown "$( stat -c %U . ):$( stat -c %G . )" "${TESTDIR}/${ZBM_POOL}.key"

  if ! ENCRYPT_KEYFILE="$( realpath -e "${TESTDIR}/${ZBM_POOL}.key" )"; then
    echo "ERROR: unable to find real path to encryption keyfile"
    exit 1
  fi

  export ENCRYPT_KEYFILE
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
      "${ZBM_POOL}" "${LOOP_DEV}"; then
  export ZBM_POOL="${ZBM_POOL}"
else
  echo "ERROR: unable to create pool ${ZBM_POOL}"
  exit 1
fi

if [ -n "${ENCRYPT}" ]; then
  zfs set "keylocation=file:///etc/zfs/${ZBM_POOL}.key" "${ZBM_POOL}"
fi

zfs snapshot -r "${ZBM_POOL}@barepool"

zfs create -o mountpoint=none "${ZBM_POOL}/ROOT"
zfs create -o mountpoint=/ -o canmount=noauto "${ZBM_POOL}/ROOT/${DISTRO}"

zfs snapshot -r "${ZBM_POOL}@barebe"

zfs set org.zfsbootmenu:commandline="spl_hostid=$( hostid ) rw loglevel=4 console=tty1 console=ttyS0" "${ZBM_POOL}/ROOT"
zpool set bootfs="${ZBM_POOL}/ROOT/${DISTRO}" "${ZBM_POOL}"

zpool export "${ZBM_POOL}"

zpool import -o cachefile=none -R "${CHROOT_MNT}" "${ZBM_POOL}" || exit 1

if [ -r "${ENCRYPT_KEYFILE}" ]; then
  zfs load-key -L "file://${ENCRYPT_KEYFILE}" "${ZBM_POOL}"
fi

zfs mount "${ZBM_POOL}/ROOT/${DISTRO}" || exit 1

if ! "${INSTALL_SCRIPT}"; then
  echo "ERROR: install script '${INSTALL_SCRIPT}' failed"
  exit 1
fi

zfs snapshot -r "${ZBM_POOL}@pre-chroot"

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

# Launch the chroot script
if ! chroot "${CHROOT_MNT}" "/root/${CHROOT_SCRIPT##*/}"; then
  echo "ERROR: chroot script '${CHROOT_SCRIPT}' failed"
  exit 1
fi

zfs snapshot -r "${ZBM_POOL}@full-setup"

touch "${CHROOT_MNT}/root/IN_THE_MATRIX"
zfs snapshot -r "${ZBM_POOL}@minor-changes"

rm "${CHROOT_MNT}/root/IN_THE_MATRIX"
rm "${CHROOT_MNT}/root/${CHROOT_SCRIPT##*/}"

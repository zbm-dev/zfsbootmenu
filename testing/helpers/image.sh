#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

#TESTDIR="${1?Usage: $0 <testdir> <size> <distro>}"
#SIZE="${2?Usage: $0 <testdir> <size> <distro>}"
#DISTRO="${3?Usage: $0 <testdir> <size> <distro>}"

if [ -z "${TESTDIR}" ] || [ ! -d "${TESTDIR}" ]; then
  echo "ERROR: test directory must be specified and must exist"
  exit 1
fi

MNT="$( mktemp -d )" || exit 1
CHROOT_MNT="${MNT}"
export CHROOT_MNT

# shellcheck disable=SC2064
trap "rmdir '${MNT}'" EXIT

qemu-img create "${TESTDIR}/zfsbootmenu-pool.img" "${SIZE}"
chown "$( stat -c %U . ):$( stat -c %G . )" "${TESTDIR}/zfsbootmenu-pool.img"

LOOP="$( losetup -f )" || exit 1
losetup "${LOOP}" "${TESTDIR}/zfsbootmenu-pool.img" || exit 1
# shellcheck disable=SC2064
trap "rmdir '${MNT}'; losetup -d '${LOOP}'" EXIT

kpartx -u "${LOOP}"

echo 'label: gpt' | sfdisk "${LOOP}"

if [ -n "${ENCRYPT}" ]; then
  ENCRYPT_OPTS=( "-O" "encryption=aes-256-gcm" "-O" "keyformat=passphrase" )

  echo "zfsbootmenu" > "${TESTDIR}/ztest.key"
  if [ ! -r "${TESTDIR}/ztest.key" ]; then
    echo "ERROR: unable to read encryption keyfile"
    exit 1
  fi

  chown "$( stat -c %U . ):$( stat -c %G . )" "${TESTDIR}/ztest.key"

  if ! ENCRYPT_KEYFILE="$( realpath -e "${TESTDIR}/ztest.key" )"; then
    echo "ERROR: unable to find real path to encryption keyfile"
    exit 1
  fi

  export ENCRYPT_KEYFILE
  ENCRYPT_OPTS+=( "-O" "keylocation=file://${ENCRYPT_KEYFILE}" )
fi

zpool create -f \
  -O compression=lz4 \
  -O acltype=posixacl \
  -O xattr=sa \
  -O relatime=on \
  -o autotrim=on \
  -o cachefile=none \
  "${ENCRYPT_OPTS[@]}" \
  -m none ztest "${LOOP}"

if [ -n "${ENCRYPT}" ]; then
  zfs set "keylocation=file:///etc/zfs/ztest.key" ztest
fi

zfs snapshot -r ztest@barepool

zfs create -o mountpoint=none ztest/ROOT
zfs create -o mountpoint=/ -o canmount=noauto "ztest/ROOT/${DISTRO}"

zfs snapshot -r ztest@barebe

zfs set org.zfsbootmenu:commandline="spl_hostid=$( hostid ) rw quiet" ztest/ROOT
zpool set bootfs="ztest/ROOT/${DISTRO}" ztest

zpool export ztest

zpool import -o cachefile=none -R "${MNT}" ztest || exit 1

if [ -r "${ENCRYPT_KEYFILE}" ]; then
  zfs load-key -L "file://${ENCRYPT_KEYFILE}" ztest
fi

# shellcheck disable=SC2064
trap "umount -R '${CHROOT_MNT}'; zpool export ztest; rmdir '${CHROOT_MNT}'; losetup -d '${LOOP}'" EXIT

zfs mount "ztest/ROOT/${DISTRO}" || exit 1

INSTALL_SCRIPT="./helpers/install-${DISTRO}.sh"
if [ -x "${INSTALL_SCRIPT}" ]; then
  "${INSTALL_SCRIPT}"
else
  echo "Install script: ${INSTALL_SCRIPT} missing or not executable"
  exit 1
fi

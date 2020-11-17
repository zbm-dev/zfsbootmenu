#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

TESTDIR="${1?Usage: $0 <testdir> <size>}"
SIZE="${2?Usage: $0 <testdir> <size>}"

if [ -z "${TESTDIR}" ] || [ ! -d "${TESTDIR}" ]; then
  echo "ERROR: test directory must be specified and must exist"
  exit 1
fi

XBPS_ARCH="$(uname -m)"

case "${XBPS_ARCH}" in
  ppc64le)
    URL="https://mirrors.servercentral.com/void-ppc/current"
    ;;
  x86_64)
    URL="https://mirrors.servercentral.com/voidlinux/current"
    ;;
  *)
    echo "ERROR: unsupported architecture"
    exit 1
    ;;
esac

if [ -n "${MUSL}" ]; then
  URL="${URL}/musl"
  XBPS_ARCH="${XBPS_ARCH}-musl"
fi

export XBPS_ARCH

MNT="$( mktemp -d )" || exit 1
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
zfs create -o mountpoint=/ -o canmount=noauto ztest/ROOT/void

zfs snapshot -r ztest@barebe

zfs set org.zfsbootmenu:commandline="spl_hostid=$( hostid ) ro quiet" ztest/ROOT
zpool set bootfs=ztest/ROOT/void ztest

zpool export ztest

zpool import -o cachefile=none -R "${MNT}" ztest || exit 1
# shellcheck disable=SC2064
trap "zpool export ztest; rmdir '${MNT}'; losetup -d '${LOOP}'" EXIT

if [ -r "${ENCRYPT_KEYFILE}" ]; then
  zfs load-key -L "file://${ENCRYPT_KEYFILE}" ztest
fi

zfs mount ztest/ROOT/void || exit 1
# shellcheck disable=SC2064
trap "umount -R '${MNT}'; zpool export ztest; rmdir '${MNT}'; losetup -d '${LOOP}'" EXIT

# https://github.com/project-trident/trident-installer/blob/master/src-sh/void-install-zfs.sh#L541
mkdir -p "${MNT}/var/db/xbps/keys"
cp /var/db/xbps/keys/*.plist "${MNT}/var/db/xbps/keys/."

mkdir -p "${MNT}/etc/xbps.d"
cp /etc/xbps.d/*.conf "${MNT}/etc/xbps.d/."

if [ -r "${ENCRYPT_KEYFILE}" ]; then
  mkdir -p "${MNT}/etc/zfs"
  cp "${ENCRYPT_KEYFILE}" "${MNT}/etc/zfs/"
fi

# /etc/runit/core-services/03-console-setup.sh depends on loadkeys from kbd
# /etc/runit/core-services/05-misc.sh depends on ip from iproute2
xbps-install -y -M -r "${MNT}" --repository="${URL}" \
  base-minimal dracut ncurses-base kbd iproute2 dhclient openssh

cp /etc/hostid "${MNT}/etc/"
cp /etc/resolv.conf "${MNT}/etc/"
cp /etc/rc.conf "${MNT}/etc/"

mkdir -p "${MNT}/etc/xbps.d"
echo "repository=${URL}" > "${MNT}/etc/xbps.d/00-repository-main.conf"

mount -t proc proc "${MNT}/proc"
mount -t sysfs sys "${MNT}/sys"
mount -B /dev "${MNT}/dev"
mount -t devpts pts "${MNT}/dev/pts"

zfs snapshot -r ztest@pre-chroot

cp chroot.sh "${MNT}/root"
chroot "${MNT}" /root/chroot.sh

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

zpool create -f \
  -O compression=lz4 \
  -O acltype=posixacl \
  -O xattr=sa \
  -O relatime=on \
  -o autotrim=on \
  -o cachefile=none \
  -m none ztest "${LOOP}"

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

zfs mount ztest/ROOT/void || exit 1
# shellcheck disable=SC2064
trap "umount -R '${MNT}'; zpool export ztest; rmdir '${MNT}'; losetup -d '${LOOP}'" EXIT

# https://github.com/project-trident/trident-installer/blob/master/src-sh/void-install-zfs.sh#L541
mkdir -p "${MNT}/var/db/xbps/keys"
cp /var/db/xbps/keys/*.plist "${MNT}/var/db/xbps/keys/."

mkdir -p "${MNT}/etc/xbps.d"
cp /etc/xbps.d/*.conf "${MNT}/etc/xbps.d/."

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

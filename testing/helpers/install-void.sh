#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

if [ -z "${CHROOT_MNT}" ] || [ ! -d "${CHROOT_MNT}" ]; then
  echo "ERROR: chroot mountpoint must be specified and must exist"
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

# https://github.com/project-trident/trident-installer/blob/master/src-sh/void-install-zfs.sh#L541
mkdir -p "${CHROOT_MNT}/var/db/xbps/keys"
cp /var/db/xbps/keys/*.plist "${CHROOT_MNT}/var/db/xbps/keys/."

mkdir -p "${CHROOT_MNT}/etc/xbps.d"
cp /etc/xbps.d/*.conf "${CHROOT_MNT}/etc/xbps.d/."

if [ -r "${ENCRYPT_KEYFILE}" ]; then
  mkdir -p "${CHROOT_MNT}/etc/zfs"
  cp "${ENCRYPT_KEYFILE}" "${CHROOT_MNT}/etc/zfs/"
fi

# /etc/runit/core-services/03-console-setup.sh depends on loadkeys from kbd
# /etc/runit/core-services/05-misc.sh depends on ip from iproute2
xbps-install -y -M -r "${CHROOT_MNT}" --repository="${URL}" \
  base-minimal dracut ncurses-base kbd iproute2 dhclient openssh

cp /etc/hostid "${CHROOT_MNT}/etc/"
cp /etc/resolv.conf "${CHROOT_MNT}/etc/"
cp /etc/rc.conf "${CHROOT_MNT}/etc/"

mkdir -p "${CHROOT_MNT}/etc/xbps.d"
echo "repository=${URL}" > "${CHROOT_MNT}/etc/xbps.d/00-repository-main.conf"

mount -t proc proc "${CHROOT_MNT}/proc"
mount -t sysfs sys "${CHROOT_MNT}/sys"
mount -B /dev "${CHROOT_MNT}/dev"
mount -t devpts pts "${CHROOT_MNT}/dev/pts"

zfs snapshot -r ztest@pre-chroot

cp "helpers/chroot-void.sh" "${CHROOT_MNT}/root"
chroot "${CHROOT_MNT}" /root/chroot-void.sh

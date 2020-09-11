#!/bin/bash

MNT="$( mktemp -d )"
LOOP="$( losetup -f )"

qemu-img create zfsbootmenu-pool.img 1G

losetup "${LOOP}" zfsbootmenu-pool.img
kpartx -u "${LOOP}"

echo 'label: gpt' | sfdisk "${LOOP}"
zpool create -f \
 -O compression=lz4 \
 -O acltype=posixacl \
 -O xattr=sa \
 -O relatime=on \
 -o autotrim=on \
 -m none ztest "${LOOP}"

zfs create -o mountpoint=none ztest/ROOT
zfs create -o mountpoint=/ -o canmount=noauto ztest/ROOT/void
zfs set org.zfsbootmenu:commandline="spl_hostid=$( hostid ) ro quiet" ztest/ROOT
zpool set bootfs=ztest/ROOT/void ztest

zpool export ztest
zpool import -R "${MNT}" ztest
zfs mount ztest/ROOT/void

case "$(uname -m)" in
  ppc64le)
    URL="https://mirrors.servercentral.com/void-ppc/current"
    ;;
  x86_64)
    URL="https://mirrors.servercentral.com/voidlinux/current"
    ;;
esac

# https://github.com/project-trident/trident-installer/blob/master/src-sh/void-install-zfs.sh#L541
mkdir -p "${MNT}/var/db/xbps/keys"
cp /var/db/xbps/keys/*.plist "${MNT}/var/db/xbps/keys/."

mkdir -p "${MNT}/etc/xbps.d"
cp /etc/xbps.d/*.conf "${MNT}/etc/xbps.d/."

# /etc/runit/core-services/03-console-setup.sh depends on loadkeys from kbd
# /etc/runit/core-services/05-misc.sh depends on ip from iproute2
xbps-install -y -S -M -r "${MNT}" --repository="${URL}" \
  base-minimal dracut ncurses-base kbd iproute2

cp /etc/hostid "${MNT}/etc/"
cp /etc/resolv.conf "${MNT}/etc/" 
cp /etc/rc.conf "${MNT}/etc/"

mount -t proc proc "${MNT}/proc"
mount -t sysfs sys "${MNT}/sys"
mount -B /dev "${MNT}/dev"
mount -t devpts pts "${MNT}/dev/pts"

cp chroot.sh "${MNT}/root"
chroot "${MNT}" /root/chroot.sh

umount -R "${MNT}" && rmdir "${MNT}"

zpool export ztest
losetup -d "${LOOP}"

chown "$( stat -c %U . ):$( stat -c %G . )" zfsbootmenu-pool.img

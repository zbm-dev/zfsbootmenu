#!/bin/bash

MNT="$( mktemp -d )"

qemu-img create zfsbootmenu-pool.img 1G
losetup /dev/loop0 zfsbootmenu-pool.img
kpartx -u /dev/loop0
echo 'label: gpt' | sfdisk /dev/loop0
zpool create -f \
 -O compression=lz4 \
 -O acltype=posixacl \
 -O xattr=sa \
 -O relatime=on \
 -o autotrim=on \
 -m none ztest /dev/loop0

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

xbps-install -y -S -r "${MNT}" --repository="${URL}"

# /etc/runit/core-services/03-console-setup.sh depends on loadkeys from kbd
# /etc/runit/core-services/05-misc.sh depends on ip from iproute2
xbps-install -y -r "${MNT}" --repository="${URL}" \
  base-minimal dracut ncurses-base kbd iproute2

cp /etc/hostid "${MNT}/etc/"
cp /etc/resolv.conf "${MNT}/etc/" 

mount -t proc proc "${MNT}/proc"
mount -t sysfs sys "${MNT}/sys"
mount -B /dev "${MNT}/dev"
mount -t devpts pts "${MNT}/dev/pts"

cp chroot.sh "${MNT}/root"
chroot "${MNT}" /root/chroot.sh

umount -R "${MNT}" && rmdir "${MNT}"

zpool export ztest
losetup -d /dev/loop0

chown "$( stat -c %U . ):$( stat -c %G . )" zfsbootmenu-pool.img

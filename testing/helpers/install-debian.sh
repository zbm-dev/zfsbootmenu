#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

if [ -z "${CHROOT_MNT}" ] || [ ! -d "${CHROOT_MNT}" ]; then
  echo "ERROR: chroot mountpoint must be specified and must exist"
  exit 1
fi

if [[ "$0" =~ "ubuntu" ]]; then
  ./helpers/debootstrap.sh focal "${CHROOT_MNT}" http://us.archive.ubuntu.com/ubuntu/
else
  ./helpers/debootstrap.sh buster "${CHROOT_MNT}"
fi

cp /etc/hostid "${CHROOT_MNT}/etc/"
cp /etc/resolv.conf "${CHROOT_MNT}/etc/"

# Add network configuration script
if [ -x ./helpers/network-systemd.sh ]; then
  mkdir -p "${CHROOT_MNT}/root"
  cp ./helpers/network-systemd.sh "${CHROOT_MNT}/root/"
fi

# Add ZFSBootMenu population script
if [ -x ./helpers/zbm-populate.sh ]; then
  mkdir -p "${CHROOT_MNT}/root"
  cp ./helpers/zbm-populate.sh "${CHROOT_MNT}/root/"
fi

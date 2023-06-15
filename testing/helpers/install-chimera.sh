#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

if [ -z "${CHROOT_MNT}" ] || [ ! -d "${CHROOT_MNT}" ]; then
  echo "ERROR: chroot mountpoint must be specified and must exist"
  exit 1
fi

LIVE="https://repo.chimera-linux.org/live/latest/"

PATTERN="chimera-linux-x86_64-ROOTFS-[0-9]\+-full\.tar\.gz"
if ! ./helpers/extract_remote.sh "${LIVE}" "${CHROOT_MNT}" "${PATTERN}"; then
  echo "ERROR: could not fetch and extract Chimera bootstrap image"
  exit 1
fi

cp /etc/hostid "${CHROOT_MNT}/etc/"
mv "${CHROOT_MNT}/etc/resolv.conf" "${CHROOT_MNT}/etc/resolv.conf.orig"
cp /etc/resolv.conf "${CHROOT_MNT}/etc/"

# Add ZFSBootMenu population script
if [ -x ./helpers/zbm-populate.sh ]; then
  mkdir -p "${CHROOT_MNT}/root"
  cp ./helpers/zbm-populate.sh "${CHROOT_MNT}/root/"
fi

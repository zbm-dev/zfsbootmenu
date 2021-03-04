#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

if [ -z "${CHROOT_MNT}" ] || [ ! -d "${CHROOT_MNT}" ]; then
  echo "ERROR: chroot mountpoint must be specified and must exist"
  exit 1
fi

if [ -r "${ENCRYPT_KEYFILE}" ]; then
  mkdir -p "${CHROOT_MNT}/etc/zfs"
  cp "${ENCRYPT_KEYFILE}" "${CHROOT_MNT}/etc/zfs/"
fi

debootstrap focal "${CHROOT_MNT}" http://us.archive.ubuntu.com/ubuntu/

cp /etc/hostid "${CHROOT_MNT}/etc/"
cp /etc/resolv.conf "${CHROOT_MNT}/etc/"

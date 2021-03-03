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

debootstrap buster "${CHROOT_MNT}"

cp /etc/hostid "${CHROOT_MNT}/etc/"
cp /etc/resolv.conf "${CHROOT_MNT}/etc/"

mount -t proc proc "${CHROOT_MNT}/proc"
mount -t sysfs sys "${CHROOT_MNT}/sys"
mount -B /dev "${CHROOT_MNT}/dev"
mount -t devpts pts "${CHROOT_MNT}/dev/pts"

zfs snapshot -r ztest@pre-chroot

cp "helpers/chroot-debian.sh" "${CHROOT_MNT}/root"
chroot "${CHROOT_MNT}" /root/chroot-debian.sh

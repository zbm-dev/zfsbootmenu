#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# shellcheck disable=SC1091
test -f /lib/zfsbootmenu-lib.sh && source /lib/zfsbootmenu-lib.sh
# shellcheck disable=SC1091
test -f zfsbootmenu-lib.sh && source zfsbootmenu-lib.sh

selected="${1}"

zdebug "started with ${selected}"

[ -n "${selected}" ] || exit 0

if mountpoint="$( allow_rw=yes mount_zfs "${selected}" )"; then
  zdebug "Mounted ${selected} to ${mountpoint}"
  mount -t proc proc "${mountpoint}/proc"
  mount -t sysfs sys "${mountpoint}/sys"
  mount -B /dev "${mountpoint}/dev"
  mount -B /tmp "${mountpoint}/var/tmp"
  mount -t devpts pts "${mountpoint}/dev/pts"

  tput clear
  tput cnorm

  pool="${selected%%/*}"

  if is_writable "${pool}"; then
    echo "${selected} is mounted read/write"
  else
    echo "${selected} is mounted read-only"
  fi

  if [ -f "${mountpoint}/bin/bash" ]; then
    _SHELL="/bin/bash"
  else
    _SHELL="/bin/sh"
  fi

  # regardless of shell, set PS1
  env "PS1=${selected} > " chroot "${mountpoint}" "${_SHELL}"

  if ! umount -R "${mountpoint}"; then
    zdebug "unable to unmount ${mountpoint}"
  fi
fi

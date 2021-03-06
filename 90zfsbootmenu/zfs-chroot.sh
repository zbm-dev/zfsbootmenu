#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# shellcheck disable=SC1091
[ -r /lib/zfsbootmenu-lib.sh ] && source /lib/zfsbootmenu-lib.sh

selected="${1}"

zdebug "started with ${selected}"

[ -n "${selected}" ] || exit 0

if mountpoint="$( allow_rw=yes mount_zfs "${selected}" )"; then
  zdebug "Mounted ${selected} to ${mountpoint}"
  mount -t proc proc "${mountpoint}/proc"
  mount -t sysfs sys "${mountpoint}/sys"
  mount -B /dev "${mountpoint}/dev"
  mount -B /tmp "${mountpoint}/tmp"
  mount -t devpts pts "${mountpoint}/dev/pts"

  pool="${selected%%/*}"

  # Snapshots and read-only pools always produce read-only mounts
  if [[ "${selected}" =~ @ ]] || ! is_writable "${pool}"; then
    writemode="$( colorize green "read-only")"
  else
    writemode="$( colorize red "read/write")"
  fi

  _SHELL=
  if [ -x "${mountpoint}/bin/bash" ] \
    && chroot "${mountpoint}" /bin/bash -c "exit 0" >/dev/null 2>&1 ; then
    _SHELL="/bin/bash"
    chroot_extra="--norc"
  elif [ -x "${mountpoint}/bin/sh" ] \
    && chroot "${mountpoint}" /bin/sh -c "exit 0" >/dev/null 2>&1 ; then
    _SHELL="/bin/sh"
  else
    zerror "unable to test execute a shell in ${selected}"
  fi

  if [ -n "${_SHELL}" ]; then
    echo -e "$( colorize orange "${selected}") is mounted ${writemode}, /tmp is shared and read/write\n"

    # regardless of shell, set PS1
    if ! env "PS1=$( colorize orange "${selected}") \w > " chroot "${mountpoint}" "${_SHELL}" "${chroot_extra}" ; then
      zdebug "chroot ${selected}:${_SHELL} returned code $?"
    fi
  fi

  if ! umount -R "${mountpoint}"; then
    zerror "unable to unmount ${mountpoint}"
  fi
fi

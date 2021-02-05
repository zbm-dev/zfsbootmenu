#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# shellcheck disable=SC1091
. /lib/dracut-lib.sh

# Let the command line override our host id.
spl_hostid=$(getarg spl_hostid=)
if [ -n "${spl_hostid}" ] ; then
  info "ZFSBootMenu: Using hostid from command line: ${spl_hostid}"
  echo -ne "\\x${spl_hostid:6:2}\\x${spl_hostid:4:2}\\x${spl_hostid:2:2}\\x${spl_hostid:0:2}" >/etc/hostid
elif [ -f "/etc/hostid" ] ; then
  info "ZFSBootMenu: Using hostid from /etc/hostid: $(hostid)"
else
  warn "ZFSBootMenu: No hostid found on kernel command line or /etc/hostid."
  warn "ZFSBootMenu: Pools may not import correctly."
fi

# Use the last defined console= to control menu output
control_term=$( getarg console=)
if [ -n "${control_term}" ]; then
  info "ZFSBootMenu: Setting controlling terminal to: ${control_term}"
  control_term="/dev/${control_term}"
else
  control_term="/dev/tty1"
  info "ZFSBootMenu: Defaulting controlling terminal to: ${control_term}"
fi

# Use loglevel to determine logging to /dev/kmsg
loglevel=$( getarg loglevel=)
if [ -n "${loglevel}" ]; then
  info "ZFSBootMenu: setting log level from command line: ${loglevel}"
else
  loglevel=3
fi

# Force import pools only when explicitly told to do so
if getargbool 0 zbm.force_import -d force_import ; then
  # shellcheck disable=SC2034
  force_import="yes"
  info "ZFSBootMenu: Enabling force import of ZFS pools"
fi

# zbm.timeout= overrides timeout=
menu_timeout=$( getarg zbm.timeout -d timeout )
if [ -n "${menu_timeout}" ]; then
  info "ZFSBootMenu: Setting menu timeout from command line: ${menu_timeout}"
elif getargbool 0 zbm.show ; then
  menu_timeout=-1;
  info "ZFSBootMenu: forcing display of menu"
elif getargbool 0 zbm.skip ; then
  menu_timeout=0;
  info "ZFSBootMenu: skipping display of menu"
else
  menu_timeout=10
fi

# Allow setting of console size; there are no defaults here
# shellcheck disable=SC2034
zbm_lines=$( getarg zbm.lines=)
# shellcheck disable=SC2034
zbm_columns=$( getarg zbm.columns=)

# Allow sorting based on a key. Accept any value, default to name.
zbm_sort=
sort_key=$( getarg zbm.sort_key=)
if [ -n "${sort_key}" ]; then
  zbm_sort="${sort_key}"
  info "ZFSBootMenu: Setting sort key to ${zbm_sort}"

  for key in "name" "creation"; do
    if [ "${key}" != "${sort_key}" ]; then
      zbm_sort="${zbm_sort};${key}"
    fi
  done
else
  zbm_sort="name;creation"
  info "ZFSBootMenu: Defaulting sort key order to ${zbm_sort}"
fi

# Turn on tmux integrations
# shellcheck disable=SC2034
if getargbool 0 zbm.tmux ; then
  zbm_tmux="yes"
  info "ZFSBootMenu: Enabling tmux integrations"
fi

wait_for_zfs=0
case "${root}" in
  ""|zfsbootmenu|zfsbootmenu:)
    # We'll take root unset, root=zfsbootmenu, or root=zfsbootmenu:
    root="zfsbootmenu"
    # shellcheck disable=SC2034
    rootok=1
    wait_for_zfs=1

    info "ZFSBootMenu: Enabling menu after udev settles"
    ;;
  zfsbootmenu:POOL=*)
    # Prefer a specific pool for bootfs value, root=zfsbootmenu:POOL=zroot
    root="${root#zfsbootmenu:POOL=}"
    # shellcheck disable=SC2034
    rootok=1
    wait_for_zfs=1

    info "ZFSBootMenu: Preferring ${root} for bootfs"
    ;;
esac

# Make sure Dracut is happy that we have a root and will wait for ZFS
# modules to settle before mounting.
if [ ${wait_for_zfs} -eq 1 ]; then
  ln -s /dev/null /dev/root 2>/dev/null
  # shellcheck disable=SC2154
  initqueuedir="${hookdir}/initqueue/finished"
  [ -d "${initqueuedir}" ] || initqueuedir="${hookdir}/initqueue-finished"
  echo '[ -e /dev/zfs ]' > "${initqueuedir}/zfs.sh"
fi

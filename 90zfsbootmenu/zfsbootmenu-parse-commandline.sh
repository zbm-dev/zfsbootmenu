#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# shellcheck disable=SC1091
. /lib/dracut-lib.sh

# Let the command line override our host id.
spl_hostid=$(getarg spl_hostid=)
if [ -n "${spl_hostid}" ] ; then
  info "ZFSBootMenu: using hostid from command line: ${spl_hostid}"
  echo -ne "\\x${spl_hostid:6:2}\\x${spl_hostid:4:2}\\x${spl_hostid:2:2}\\x${spl_hostid:0:2}" >/etc/hostid
elif [ -f "/etc/hostid" ] ; then
  info "ZFSBootMenu: using hostid from /etc/hostid: $(hostid)"
else
  warn "ZFSBootMenu: no hostid found on kernel command line or /etc/hostid"
  warn "ZFSBootMenu: pools may not import correctly"
fi

# Use the last defined console= to control menu output
control_term=$( getarg console=)
if [ -n "${control_term}" ]; then
  info "ZFSBootMenu: setting controlling terminal to: ${control_term}"
  control_term="/dev/${control_term}"
else
  control_term="/dev/tty1"
  info "ZFSBootMenu: defaulting controlling terminal to: ${control_term}"
fi

# Use loglevel to determine logging to /dev/kmsg
loglevel=$( getarg loglevel=)
if [ -n "${loglevel}" ]; then
  # minimum log level of 3, so we never lose error messages
  [ "${loglevel}" -ge 3 ] || loglevel=3
  info "ZFSBootMenu: setting log level from command line: ${loglevel}"
else
  loglevel=3
fi

import_policy=$( getarg zbm.import_policy )
if [ -n "${import_policy}" ]; then
  case "${import_policy}" in
    hostid)
      info "ZFSBootMenu: setting import_policy to hostid matching, read-only"
      ;;
    force)
      info "ZFSBootMenu: setting import_policy to force"
      ;;
    *)
      info "ZFSBootMenu: unknown import policy ${import_policy}, defaulting to hostid"
      import_policy="hostid"
      ;;
  esac
elif getargbool 0 zbm.force_import -d force_import ; then
  import_policy="force"
  info "ZFSBootMenu: setting import_policy to force"
else
  info "ZFSBootMenu: defaulting import_policy to hostid matching, read-only"
  import_policy="hostid"
fi

# zbm.timeout= overrides timeout=
menu_timeout=$( getarg zbm.timeout -d timeout )
if [ -n "${menu_timeout}" ]; then
  info "ZFSBootMenu: setting menu timeout from command line: ${menu_timeout}"
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

# Allow sorting based on a key
zbm_sort=
sort_key=$( getarg zbm.sort_key=)
if [ -n "${sort_key}" ] ; then
  valid_keys=( "name" "creation" "used" )
  for key in "${valid_keys[@]}"; do
    if [ "${key}" == "${sort_key}" ]; then
      zbm_sort="${key}"
    fi
  done

  # If zbm_sort is empty (invalid user provided key)
  # Default the starting sort key to 'name'
  if [ -z "${zbm_sort}" ] ; then
    sort_key="name"
    zbm_sort="name"
  fi

  # Append any other sort keys to the selected one
  for key in "${valid_keys[@]}"; do
    if [ "${key}" != "${sort_key}" ]; then
      zbm_sort="${zbm_sort};${key}"
    fi
  done

  info "ZFSBootMenu: setting sort key order to ${zbm_sort}"
else
  zbm_sort="name;creation;used"
  info "ZFSBootMenu: defaulting sort key order to ${zbm_sort}"
fi


# Turn on tmux integrations
# shellcheck disable=SC2034
if getargbool 0 zbm.tmux ; then
  zbm_tmux=1
  info "ZFSBootMenu: enabling tmux integrations"
fi

# Do not automatically set spl_hostid on the BE KCL
# shellcheck disable=SC2034
if getargbool 0 zbm.set_hostid ; then
  zbm_set_hostid=0
  info "ZFSBootMenu: disabling automatic replacement of spl_hostid"
else
  zbm_set_hostid=1
  info "ZFSBootMenu: defaulting automatic replacement of spl_hostid to on"
fi


wait_for_zfs=0
case "${root}" in
  ""|zfsbootmenu|zfsbootmenu:)
    # We'll take root unset, root=zfsbootmenu, or root=zfsbootmenu:
    root="zfsbootmenu"
    # shellcheck disable=SC2034
    rootok=1
    wait_for_zfs=1

    info "ZFSBootMenu: enabling menu after udev settles"
    ;;
  zfsbootmenu:POOL=*)
    # Prefer a specific pool for bootfs value, root=zfsbootmenu:POOL=zroot
    root="${root#zfsbootmenu:POOL=}"
    # shellcheck disable=SC2034
    rootok=1
    wait_for_zfs=1

    info "ZFSBootMenu: preferring ${root} for bootfs"
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

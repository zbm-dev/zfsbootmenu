#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# disable ctrl-c (SIGINT)
trap '' SIGINT

# shellcheck disable=SC1091
[ -r /lib/zfsbootmenu-lib.sh ] && source /lib/zfsbootmenu-lib.sh

if [ -z "${BASE}" ]; then
  export BASE="/zfsbootmenu"
fi

mkdir -p "${BASE}"

# Write out a default or overridden hostid
if [ -n "${spl_hostid}" ] ; then
  zinfo "ZFSBootMenu: writing /etc/hostid from command line: ${spl_hostid}"
  write_hostid "${spl_hostid}"
elif [ ! -e /etc/hostid ]; then
  zinfo "ZFSBootMenu: no hostid found on kernel command line or /etc/hostid"
  zinfo "ZFSBootMenu: defaulting hostid to 00000000"
  write_hostid 0
fi

# Prefer a specific pool when checking for a bootfs value
# shellcheck disable=SC2154
if [ "${root}" = "zfsbootmenu" ]; then
  boot_pool=
else
  boot_pool="${root}"
fi

first_pass=0

while true; do

  # Make every attempt to import the specified boot pool
  if [ -n "${boot_pool}" ] && [ "${first_pass}" -eq 0 ] ; then
    zdebug "first pass, attempting to import ${boot_pool}"

    # try to import the preferred pool with the initial hostid
    # shellcheck disable=SC2154
    if read_write='' import_pool "${boot_pool}" ; then
      zdebug "imported preferred boot pool ${boot_pool}"

    # try to import the preferred pool by matching it's hostid
    elif [ "${import_policy}" == "hostid" ] && poolmatch="$( match_hostid "${boot_pool}" )"; then
      zdebug "match_hostid returned: ${poolmatch}"

      pool="${poolmatch%%;*}"
      spl_hostid="${poolmatch##*;}"

      zdebug "first pass, match_hostid imported ${pool}"
      export spl_hostid

      # Store the hostid to use for for KCL overrides
      echo -n "$spl_hostid" > "${BASE}/spl_hostid"
    fi
  fi

  # We've made every attempt to import boot_pool, don't explicitly try again
  first_pass=1

  # if at least one pool has been imported, no longer modify /etc/hostid
  if check_for_pools ; then
    # Attempt to import all other pools read-only
    zdebug "attempting to import all other pools"
    read_write='' all_pools=yes import_pool
    break

  # boot_pool couldn't be imported, so now try to find any hostid and import pools
  elif [ "${import_policy}" == "hostid" ] && poolmatch="$( match_hostid )"; then
    zdebug "match_hostid returned: ${poolmatch}"

    pool="${poolmatch%%;*}"
    spl_hostid="${poolmatch##*;}"

    zdebug "tried to match hostid from any pool and import, imported ${pool}"

    export spl_hostid

    # Store the hostid to use for for KCL overrides
    echo -n "$spl_hostid" > "${BASE}/spl_hostid"

    # Retry the import cycle with the matched hostid
    continue
  fi

  # Allow the user to attempt recovery
  emergency_shell "unable to successfully import a pool"
done

# restrict read-write access to any unhealthy pools
while IFS=$'\t' read -r _pool _health; do
  if [ "${_health}" != "ONLINE" ]; then
    echo "${_pool}" >> "${BASE}/degraded"
    zerror "prohibiting read/write operations on ${_pool}"
  fi
done <<<"$( zpool list -H -o name,health )"

zdebug "$(
  echo "zpool list" ; \
  zpool list
)"

zdebug "$(
  echo "zfs list -o name,mountpoint,encroot,keystatus,keylocation,org.zfsbootmenu:keysource" ;\
  zfs list -o name,mountpoint,encroot,keystatus,keylocation,org.zfsbootmenu:keysource
)"

# this should probably go away, we've tried every way to get boot_pool imported
# Make sure the preferred pool was imported
if [ -n "${boot_pool}" ] && ! zpool list -H -o name "${boot_pool}" >/dev/null 2>&1; then
  emergency_shell "\nCannot import requested pool '${boot_pool}'\nType 'exit' to try booting anyway"
fi

unsupported=0
while IFS=$'\t' read -r _pool _property; do
  if [[ "${_property}" =~ "unsupported@" ]]; then
    zerror "unsupported property: ${_property}"
    if ! grep -q "${_pool}" "${BASE}/degraded" >/dev/null 2>&1 ; then
      echo "${_pool}" >> "${BASE}/degraded"
    fi
    unsupported=1
  fi
done <<<"$( zpool get all -H -o name,property )"

if [ "${unsupported}" -ne 0 ]; then
  zerror "Unsupported features detected, Upgrade ZFS modules in ZFSBootMenu with generate-zbm"
  color=red timed_prompt "Unsupported features detected" "Upgrade ZFS modules in ZFSBootMenu with generate-zbm"
fi

# Attempt to find the bootfs property
# shellcheck disable=SC2086
while read -r line; do
  if [ "${line}" = "-" ]; then
    BOOTFS=
  else
    BOOTFS="${line}"
    break
  fi
done <<<"$( zpool list -H -o bootfs ${boot_pool} )"

if [ -n "${BOOTFS}" ]; then
  export BOOTFS
  echo "${BOOTFS}" > "${BASE}/bootfs"
fi

: > "${BASE}/initialized"

# If BOOTFS is not empty display the fast boot menu
if [ -n "${BOOTFS}" ]; then
  # Draw a countdown menu
  # shellcheck disable=SC2154
  if [ "${menu_timeout}" -ge 0 ]; then
    if delay="${menu_timeout}" prompt="Booting ${BOOTFS} in %0.2d seconds" timed_prompt "[ENTER] to boot" "[ESC] boot menu" ; then
      # Clear screen before a possible password prompt
      tput clear
      if ! NO_CACHE=1 load_key "${BOOTFS}"; then
        emergency_shell "unable to load key for ${BOOTFS}; type 'exit' to continue"
      elif find_be_kernels "${BOOTFS}" && [ ! -e "${BASE}/active" ]; then
        # Automatically select a kernel and boot it
        kexec_kernel "$( select_kernel "${BOOTFS}" )"
      fi
    fi
  fi
fi

while true; do
  if [ -x /bin/zfsbootmenu ]; then
    /bin/zfsbootmenu
  fi

  emergency_shell "type 'exit' to return to ZFSBootMenu"
done

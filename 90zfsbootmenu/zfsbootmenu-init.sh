#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# disable ctrl-c (SIGINT)
trap '' SIGINT

if [ -r "/etc/profile" ]; then
  # shellcheck disable=SC1091
  source /etc/profile
else
  # shellcheck disable=SC1091
  source /lib/zfsbootmenu-lib.sh
  zwarn "failed to source ZBM environment"
fi

# Prove that /lib/zfsbootmenu-lib.sh was sourced, or hard fail
if ! is_lib_sourced > /dev/null 2>&1 ; then
  echo -e "\033[0;31mWARNING: /lib/zfsbootmenu-lib.sh was not sourced; unable to proceed\033[0m"
  exec /bin/bash
fi

# Make sure /dev/zfs exists, otherwise drop to a recovery shell
[ -e /dev/zfs ] || emergency_shell "/dev/zfs missing, check that kernel modules are loaded"

if [ -z "${BASE}" ]; then
  export BASE="/zfsbootmenu"
fi

mkdir -p "${BASE}"

# Write out a default or overridden hostid
if [ -n "${spl_hostid}" ] ; then
  zinfo "writing /etc/hostid from command line: ${spl_hostid}"
  write_hostid "${spl_hostid}"
elif [ ! -e /etc/hostid ]; then
  zinfo "no hostid found on kernel command line or /etc/hostid"
  zinfo "defaulting hostid to 00bab10c"
  write_hostid 00bab10c
fi

# Prefer a specific pool when checking for a bootfs value
# shellcheck disable=SC2154
if [ "${root}" = "zfsbootmenu" ]; then
  boot_pool=
else
  boot_pool="${root}"
fi

# Do a dedicated pass for the preferred pool if one was provided
if [ -n "${boot_pool}" ]; then
  first_pass=0
else
  first_pass=1
fi

zbm_import_attempt=0
while true; do
  if [ "${first_pass}" -eq 0 ]; then
    # Try the preferred pool, exactly once
    zdebug "attempting to import preferred pool ${boot_pool}"
    try_pool="${boot_pool}"
  else
    try_pool=""
  fi

  first_pass=1

  read_write='' import_pool "${try_pool}"

  # shellcheck disable=SC2154
  if check_for_pools; then
    if [ -n "${try_pool}" ]; then
      # If a single pool was requested and imported, try again for the others
      continue
    else
      # Otherwise, all possible pools were imported, nothing more to try
      break
    fi
  elif [ "${import_policy}" == "hostid" ] && poolmatch="$( match_hostid "${try_pool}" )"; then
    zdebug "match_hostid returned: ${poolmatch}"

    spl_hostid="${poolmatch##*;}"

    export spl_hostid

    # Store the hostid to use for for KCL overrides
    echo -n "$spl_hostid" > "${BASE}/spl_hostid"

    # Retry the cycle with a matched hostid
    continue
  elif [ -n "${try_pool}" ]; then
    # Failure to import a specific pool is not an emergency;
    # subsequent import passes try all other possible pools
    continue
  fi

  if [ "${zbm_import_attempt}" -lt "${zbm_import_retries:-0}" ]; then
    # The max number of import attempts has not been reached;
    # retry unless the user decides to abort immediately
    zbm_import_attempt="$((zbm_import_attempt + 1))"

    zinfo "pool import failed on attempt ${zbm_import_attempt} of ${zbm_import_retries}"

    if delay="${zbm_import_delay:-5}" prompt="Unable to import pool, retrying in %0.2d seconds" \
        timed_prompt "[RETURN] to retry immediately" "[ESCAPE] for a recovery shell"; then
      continue
    fi
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

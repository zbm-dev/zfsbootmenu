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

while true; do
  # Attempt to import all pools read-only
  read_write='' all_pools=yes import_pool

  # Make sure at least one was imported
  import_success=0
  while IFS=$'\t' read -r _pool _health; do
    [ -n "${_pool}" ] || continue
    import_success=1

    if [ "${_health}" != "ONLINE" ]; then
      echo "${_pool}" >> "${BASE}/degraded"
      zerror "prohibiting read/write operations on ${_pool}"
    fi
  done <<<"$( zpool list -H -o name,health )"

  if [ "${import_success}" -eq 1 ]; then
    # With at least one imported pool, just move on
    zdebug "$(
      echo "zpool list" ; \
      zpool list
    )"
    zdebug "$(
      echo "zfs list -o name,mountpoint,encroot,keystatus,keylocation,org.zfsbootmenu:keysource" ;\
      zfs list -o name,mountpoint,encroot,keystatus,keylocation,org.zfsbootmenu:keysource
    )"
    break
  fi

  # shellcheck disable=SC2154
  if [ "${import_policy}" == "hostid" ] && poolmatch="$( match_hostid )"; then
    zdebug "match_hostid returned: ${poolmatch}"

    pool="${poolmatch%%;*}"
    spl_hostid="${poolmatch##*;}"

    export spl_hostid

    zerror "imported ${pool} with assumed hostid ${spl_hostid}"
    zerror "set spl_hostid=${spl_hostid} on ZBM KCL or regenerate with corrected /etc/hostid"

    # Store the hostid to use for for KCL overrides
    echo -n "$spl_hostid" > "${BASE}/spl_hostid"

    # Retry the import cycle with the matched hostid
    continue
  fi

  # Allow the user to attempt recovery
  emergency_shell "unable to successfully import a pool"
done

# Prefer a specific pool when checking for a bootfs value
# shellcheck disable=SC2154
if [ "${root}" = "zfsbootmenu" ]; then
  boot_pool=
else
  boot_pool="${root}"
fi

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

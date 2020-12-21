#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# disable ctrl-c (SIGINT)
trap '' SIGINT

# shellcheck disable=SC1091
test -f /lib/zfsbootmenu-lib.sh && source /lib/zfsbootmenu-lib.sh
# shellcheck disable=SC1091
test -f zfsbootmenu-lib.sh && source zfsbootmenu-lib.sh

if [ -z "${BASE}" ]; then
  export BASE="/zfsbootmenu"
fi

mkdir -p "${BASE}"

# Attempt to import all pools read-only
read_write='' all_pools=yes import_pool

# Make sure at least one pool can be imported; if not,
# drop to an emergency shell to allow the user to attempt recovery
import_success=0
while true; do
  while IFS=$'\t' read -r _pool _health; do
    [ -n "${_pool}" ] || continue

    import_success=1
    if [ "${_health}" != "ONLINE" ]; then
      echo "${_pool}" >> "${BASE}/degraded"
    fi
  done <<<"$( zpool list -H -o name,health )"

  if [ "${import_success}" -ne 1 ]; then
    emergency_shell "unable to successfully import a pool"
  else
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
    if ! grep -q "${_pool}" "${BASE}/degraded" >/dev/null 2>&1 ; then
      echo "${_pool}" >> "${BASE}/degraded"
    fi
    unsupported=1
  fi
done <<<"$( zpool get all -H -o name,property )"

if [ "${unsupported}" -ne 0 ]; then
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

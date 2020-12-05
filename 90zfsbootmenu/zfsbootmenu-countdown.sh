#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# store current kernel log level
read -r PRINTK < /proc/sys/kernel/printk
PRINTK=${PRINTK:0:1}
export PRINTK

# Set it to 0
echo 0 > /proc/sys/kernel/printk

# disable ctrl-c (SIGINT)
trap '' SIGINT

# shellcheck disable=SC1091
test -f /lib/zfsbootmenu-lib.sh && source /lib/zfsbootmenu-lib.sh
# shellcheck disable=SC1091
test -f zfsbootmenu-lib.sh && source zfsbootmenu-lib.sh

echo "Loading boot menu ..."
TERM=linux
tput reset

export BASE="/zfsbootmenu"
mkdir -p "${BASE}"

modprobe zfs 2>/dev/null
udevadm settle

# try to set console options for display and interaction
# this is sometimes run as an initqueue hook, but cannot be guaranteed
#shellcheck disable=SC2154
test -x /lib/udev/console_init -a -c "${control_term}" \
  && /lib/udev/console_init "${control_term##*/}" >/dev/null 2>&1

# set the console size, if indicated
#shellcheck disable=SC2154
if [ -n "$zbm_lines" ]; then
  stty rows "$zbm_lines"
fi

#shellcheck disable=SC2154
if [ -n "$zbm_columns" ]; then
  stty cols "$zbm_columns"
fi

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
  if [ "${menu_timeout}" -gt 0 ]; then
    if delay="${menu_timeout}" prompt="Booting ${BOOTFS} in %0.2d seconds" timed_prompt "[ENTER] to boot" "[ESC] boot menu" ; then
      # Clear screen before a possible password prompt
      tput clear
      if ! load_key "${BOOTFS}"; then
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

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

if [ -z "${BASE}" ]; then
  export BASE="/zfsbootmenu"
fi

mkdir -p "${BASE}"

# Write out a default or overridden hostid
if [ -n "${spl_hostid}" ] ; then
  if write_hostid "${spl_hostid}" ; then
    zinfo "writing /etc/hostid from command line: ${spl_hostid}"
  else
    # write_hostid logs an error for us, just note the new value
    # shellcheck disable=SC2154
    write_hostid "${default_hostid}"
    zinfo "defaulting hostid to ${default_hostid}"
  fi
elif [ ! -e /etc/hostid ]; then
  zinfo "no hostid found on kernel command line or /etc/hostid"
  # shellcheck disable=SC2154
  zinfo "defaulting hostid to ${default_hostid}"
  write_hostid "${default_hostid}"
fi

# only load spl.ko if it isn't already loaded
if ! lsmod | grep -E -q "^spl" ; then
  # Capture the filename for spl.ko
  _modfilename="$( modinfo -F filename spl )"
  zinfo "loading ${_modfilename}"

  # Load with a hostid of 0, so that /etc/hostid takes precedence
  if ! _modload="$( insmod "${_modfilename}" "spl_hostid=0" 2>&1 )" ; then
    zdebug "${_modload}"
    emergency_shell "unable to load SPL kernel module"
  fi
fi

if ! _modload="$( modprobe zfs 2>&1 )" ; then
  zdebug "${_modload}"
  emergency_shell "unable to load ZFS kernel modules"
fi

udevadm settle

# Prefer a specific pool when checking for a bootfs value
# shellcheck disable=SC2154
if [ "${root}" = "zfsbootmenu" ]; then
  boot_pool=
else
  boot_pool="${root}"
fi

# If a boot pool is specified, that will be tried first
try_pool="${boot_pool}"
zbm_import_attempt=0
while true; do
  if [ -n "${try_pool}" ]; then
    zdebug "attempting to import preferred pool ${try_pool}"
  fi

  read_write='' import_pool "${try_pool}"

  # shellcheck disable=SC2154
  if check_for_pools; then
    if [ -n "${try_pool}" ]; then
      # If a single pool was requested and imported, try importing others
      try_pool=""
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

    # If match_hostid succeeds, it has imported *a* pool;
    # allow another pass to pick up others with the same hostid
    try_pool=""
    continue
  elif [ -n "${try_pool}" ] && [ "${zbm_require_bpool:-0}" -ne 1 ]; then
    # If a specific pool was tried unsuccessfully but is not a requirement,
    # allow another pass to try any other importable pools
    try_pool=""
    continue
  fi

  zbm_import_attempt="$((zbm_import_attempt + 1))"
  zinfo "unable to import a pool on attempt ${zbm_import_attempt}"

  # Just keep retrying after a delay until the user presses ESC
  if delay="${zbm_import_delay:-5}" prompt="Unable to import ${try_pool:-pool}, retrying in %0.2d seconds" \
    timed_prompt "[RETURN] to retry immediately" "[ESCAPE] for a recovery shell"; then
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

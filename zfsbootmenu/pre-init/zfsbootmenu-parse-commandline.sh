#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# Critical functions
sources=(
  /lib/profiling-lib.sh
  /etc/zfsbootmenu.conf
  /lib/kmsg-log-lib.sh
  /lib/zfsbootmenu-kcl.sh
)

for src in "${sources[@]}"; do
  # shellcheck disable=SC1090
  if ! source "${src}" >/dev/null 2>&1; then
    echo -e "\033[0;31mWARNING: ${src} was not sourced, unable to proceed\033[0m"
    exec /bin/bash
  fi
done

unset src sources

# shellcheck disable=SC2154
if [ -n "${embedded_kcl}" ]; then
  mkdir -p /etc/cmdline.d/
  echo "${embedded_kcl}" > /etc/cmdline.d/zfsbootmenu.conf
fi

# Make sure a base directory exists
mkdir -p "${BASE:=/zfsbootmenu}"

# Only zwarn/zerror will log prior to loglevel being updated by a KCL argument
min_logging=4
if loglevel=$( get_zbm_arg loglevel ) ; then
  # minimum log level of 4, so we never lose error or warning messages
  if [ "${loglevel}" -ge ${min_logging} ] >/dev/null 2>&1; then
    # shellcheck disable=1091
    FORCE_RELOAD=1 source /lib/kmsg-log-lib.sh >/dev/null 2>&1
    zinfo "setting log level from command line: ${loglevel}"
  else
    loglevel=${min_logging}
  fi
else
  loglevel=${min_logging}
fi

# Let the command line override our host id.
# shellcheck disable=SC2034
if cli_spl_hostid=$( get_zbm_arg spl.spl_hostid spl_hostid ) ; then
  # Start empty so only valid hostids are set for future use
  spl_hostid=

  # Test for decimal
  if (( 10#${cli_spl_hostid} )) >/dev/null 2>&1 ; then
    spl_hostid="$( printf "%08x" "${cli_spl_hostid}" )"
  # Test for hex. Requires 0x, if present, to be stripped
  # The change to cli_spl_hostid isn't saved outside of the test
  elif (( 16#${cli_spl_hostid#0x} )) >/dev/null 2>&1 ; then
    spl_hostid="${cli_spl_hostid#0x}"
    # printf will strip leading 0s if there are more than 8 hex digits
    # normalize to a maximum of 8, then run through printf to fill in
    # if there are fewer than 8 digits.
    spl_hostid="$( printf "%08x" "0x${spl_hostid:0:8}" )"
  # base 10 / base 16 tests fail on 0
  elif [ "${cli_spl_hostid#0x}" -eq "0" ] >/dev/null 2>&1 ; then
    spl_hostid=0
  # Not valid hex or dec, log
  else
    zwarn "invalid hostid value ${cli_spl_hostid}, ignoring"
  fi
fi

# Use the last defined console= to control menu output
if control_term=$( get_zbm_arg console ) ; then
  #shellcheck disable=SC2034
  control_term="/dev/${control_term%,*}"
  zinfo "setting controlling terminal to: ${control_term}"
else
  control_term="/dev/tty1"
  zinfo "defaulting controlling terminal to: ${control_term}"
fi

# hostid - discover the hostid used to import a pool on failure, assume it
# force  - append -f to zpool import
# strict - legacy behavior, drop to an emergency shell on failure

if import_policy=$( get_zbm_arg zbm.import_policy ) ; then
  case "${import_policy}" in
    hostid)
      zinfo "setting import_policy to hostid matching"
      ;;
    force)
      zinfo "setting import_policy to force"
      ;;
    strict)
      zinfo "setting import_policy to strict"
      ;;
    *)
      zwarn "unknown import policy '${import_policy}', defaulting to hostid"
      import_policy="hostid"
      ;;
  esac
elif get_zbm_bool 0 zbm.force_import force_import ; then
  import_policy="force"
  zinfo "setting import_policy to force"
else
  zinfo "defaulting import_policy to hostid"
  import_policy="hostid"
fi

# zbm.timeout= overrides timeout=
if menu_timeout=$( get_zbm_arg zbm.timeout timeout ) ; then
  # Ensure that menu_timeout is an integer
  if ! [ "${menu_timeout}" -eq "${menu_timeout}" ] >/dev/null 2>&1; then
    zwarn "invalid menu timeout: '${menu_timeout}', defaulting to 10 seconds"
    menu_timeout=10
  else
    zinfo "setting menu timeout from command line: ${menu_timeout}"
  fi
elif get_zbm_bool 0 zbm.show ; then
  menu_timeout=-1;
  zinfo "forcing display of menu"
elif get_zbm_bool 0 zbm.skip ; then
  menu_timeout=0;
  zinfo "skipping display of menu"
else
  menu_timeout=10
  zinfo "defaulting menu timeout to ${menu_timeout}"
fi

if zbm_retry_delay=$( get_zbm_arg zbm.retry_delay zbm.import_delay ) && [ "${zbm_retry_delay:-0}" -gt 0 ] 2>/dev/null ; then
  # Again, this validates that zbm_retry_delay is numeric in addition to logging
  zinfo "import/waitfor retry delay is ${zbm_retry_delay} seconds"
else
  zbm_retry_delay=5
fi

# Allow setting of console size; ensure lines/columns are integers > 0

# shellcheck disable=SC2034
if zbm_lines=$( get_zbm_arg zbm.lines ) ; then
  if ! [ "${zbm_lines}" -gt 0 ] >/dev/null 2>&1 ; then
    zwarn "invalid zbm.lines: '${zbm_lines}', defaulting to 25 lines"
    zbm_lines=25
  fi
fi

# shellcheck disable=SC2034
if zbm_columns=$( get_zbm_arg zbm.columns ) ; then
  if ! [ "${zbm_columns}" -gt 0 ] >/dev/null 2>&1 ; then
    zwarn "invalid zbm.columns: '${zbm_columns}', defaulting to 80 columns"
    zbm_columns=80
  fi
fi

# Allow sorting based on a key
zbm_sort=
if sort_key=$( get_zbm_arg zbm.sort_key ) ; then
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

  zinfo "setting sort key order to ${zbm_sort}"
else
  zbm_sort="name;creation;used"
  zinfo "defaulting sort key order to ${zbm_sort}"
fi

# Allow hooks to be imported from another filesystem

# shellcheck disable=SC2034
zbm_hook_root=
if zbm_hook_root=$( get_zbm_arg zbm.hookroot ) ; then
  zinfo "setting user hook root to ${zbm_hook_root}"
fi

# shellcheck disable=SC2034
if get_zbm_bool 1 zbm.set_hostid ; then
  zbm_set_hostid=1
  zinfo "enabling automatic replacement of spl_hostid"
else
  zbm_set_hostid=0
  zinfo "disabling automatic replacement of spl_hostid"
fi

if kcl_override=$( get_zbm_arg zbm.kcl_override ) ; then
  # Remove the leading /  trailing quote to "unpack" this argument
  kcl_override="${kcl_override#\"}"
  kcl_override="${kcl_override%\"}"

  # Up-convert single quotes to double, for kcl_tokenize
  kcl_override="${kcl_override//\'/\"}"

  # Always strip root=
  rems+=( "root" )

  # Only strip spl hostid arguments if zbm.set_hostid is enabled
  if [ "${zbm_set_hostid}" -eq 1 ] ; then
    rems+=( "spl_hostid" "spl.spl_hostid" )
  fi

  kcl_tokenize <<< "${kcl_override}" | kcl_suppress "${rems[@]}" > "${BASE}/cmdline"
  zinfo "overriding all BE KCLs with: '$( kcl_assemble < "${BASE}/cmdline" )'"
fi

zbm_wait_for_devices=
if zbm_wait_for_devices=$( get_zbm_arg zbm.wait_for ) ; then
  zinfo "system will wait for ${zbm_wait_for_devices}"
fi

zbm_prefer_bootfs=
zbm_require_pool=
if zbm_prefer=$( get_zbm_arg zbm.prefer ) ; then

  # strip the modifiers and set zbm_require_pool as needed
  # shellcheck disable=SC2034
  case "${zbm_prefer}" in
    *!!)
      zbm_require_pool="only"
      zbm_prefer="${zbm_prefer%!!}"
      zinfo "will only attempt to import ${zbm_prefer%%/*}"
      ;;
    *!)
      zbm_require_pool="yes"
      zbm_prefer="${zbm_prefer%!}"
      zinfo "requiring pool ${zbm_prefer%%/*}"
      ;;
    *)
      zbm_require_pool=
      ;;
  esac

  zbm_prefer_pool="${zbm_prefer%%/*}"

  # zbm_prefer looks like it could be a dataset, use it as the bootfs value
  if [ "${zbm_prefer_pool}" != "${zbm_prefer}" ]; then
    # shellcheck disable=SC2034
    zbm_prefer_bootfs="${zbm_prefer}"
  fi
fi

# Make sure Dracut is happy that we have a root

# shellcheck disable=SC2034
rootok=1

# Dracut requires root to be defined
# shellcheck disable=SC2034
root=zfsbootmenu
ln -s /dev/null /dev/root 2>/dev/null

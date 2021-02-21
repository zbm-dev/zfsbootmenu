#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# shellcheck disable=SC1091
[ -r /lib/zfsbootmenu-lib.sh ] && source /lib/zfsbootmenu-lib.sh

HOSTID="00000000"
BE=

usage() {
  cat <<EOF
Usage: $0 [options]
  -h  8 digit hostid
  -b  Boot Environment

By default, a hostid of '${HOSTID}' is used.
EOF
}

rewrite_cmdline() {
  local rewritten org_cmdline
  org_cmdline="${1}"
  rewritten=()

  for token in ${org_cmdline// / } ; do
    case "${token}" in
      "-")
        break
        ;;
      spl_hostid*)
        old_hostid="${token}"
        rewritten+=( "spl_hostid=${HOSTID}" )
        zdebug "setting spl_hostid to ${HOSTID}"
        ;;
      *)
        rewritten+=( "${token}" )
        zdebug "adding token: ${token}"
        ;;
    esac
  done

  if [ -n "${old_hostid}" ] ; then
    zdebug "returning: ${rewritten[*]}"
    echo "${rewritten[*]}"
    return 0
  else
    return 1
  fi
}

while getopts "h:b:" opt; do
  case "${opt}" in
    h)
      HOSTID="${OPTARG}"
      ;;
    b)
      BE="${OPTARG}"
      ;;
    *)
      usage
      exit
    ;;
  esac
done

if [ -z "${BE}" ]; then
  usage
  exit
fi

pool="${BE%%/*}"
if set_rw_pool "${pool}" ; then
  echo "Exporting pool: ${pool}"
  export_pool "${pool}"
else
  echo "Unable to export pool ${pool}"
fi

echo -e "\nSetting SPL hostid to: ${HOSTID}"
echo -ne "\\x${HOSTID:6:2}\\x${HOSTID:4:2}\\x${HOSTID:2:2}\\x${HOSTID:0:2}" > "/etc/hostid"

read_write=1 all_pools=yes import_pool
populate_be_list "${BASE}/env" || rm -f "${BASE}/env"

echo "Setting SPL hostid in ${BE}"

MNT="$( allow_rw=1 mount_zfs "${BE}" )"
echo -ne "\\x${HOSTID:6:2}\\x${HOSTID:4:2}\\x${HOSTID:2:2}\\x${HOSTID:0:2}" > "${MNT}/etc/hostid"

org_cmdline="$( zfs get -H -o value org.zfsbootmenu:commandline "${BE}" )"

# rewrite BE commandline property
if new_cmdline="$( rewrite_cmdline "${org_cmdline}" )" ; then
  echo "Rewriting org.zfsbootmenu:commandline to:"
  echo -e "> $( colorize red "${new_cmdline}")\n"
  zfs set org.zfsbootmenu:commandline="${new_cmdline}" "${BE}"
else
  # Set a temporary cmdline for the next boot
  BE_ARGS="$( load_be_cmdline "${BE}" )"
  if override_cmdline="$( rewrite_cmdline "${BE_ARGS}" )" ; then
    echo "Writing a temporary new cmdline:"
    echo -e "> $( colorize red "${override_cmdline}")\n"
    echo "${override_cmdline}" > "${BASE}/cmdline"

  fi
fi

# restore for easy test cycling right now
zfs set org.zfsbootmenu:commandline="${org_cmdline}" "${BE}"
umount "${MNT}"

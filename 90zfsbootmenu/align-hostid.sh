#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# shellcheck source=./zfsbootmenu-lib.sh
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
echo "Exporting pool: ${pool}"
set_rw_pool "${pool}"
export_pool "${pool}"

echo "Unloading ZFS and SPL kernel modules"
modules=(
  "zfs"
  "icp"
  "zzstd"
  "zcommon"
  "znvpair"
  "zavl"
  "spl"
)

echo -n "Unloading ... "
for module in "${modules[@]}"; do
  echo -n " ${module}"
  rmmod "${module}"
done

echo -e "\nSetting SPL hostid to: ${HOSTID}"
echo -ne "\\x${HOSTID:6:2}\\x${HOSTID:4:2}\\x${HOSTID:2:2}\\x${HOSTID:0:2}" > "/etc/hostid"

modprobe zfs

read_write=1 all_pools=yes import_pool
populate_be_list "${BASE}/env" || rm -f "${BASE}/env"

echo "Setting SPL hostid in ${BE}"

MNT="$( allow_rw=1 mount_zfs "${BE}" )"
echo -ne "\\x${HOSTID:6:2}\\x${HOSTID:4:2}\\x${HOSTID:2:2}\\x${HOSTID:0:2}" > "${MNT}/etc/hostid"

BE_ARGS="$( load_be_cmdline "${BE}" )"
echo "${BE_ARGS} spl_hostid=${HOSTID}" > "${BASE}/cmdline"

org_cmdline="$( zfs get -H -o value org.zfsbootmenu:commandline "${BE}" )"

if new_cmdline="$( rewrite_cmdline "${org_cmdline}" )" ; then
	echo "Rewriting org.zfsbootmenu:commandline to: "
  echo -e "> $( colorize red "${new_cmdline}")\n"
	zfs set org.zfsbootmenu:commandline="${new_cmdline}" "${BE}"
fi

if [ -f "${MNT}/etc/zfsbootmenu/config.yaml" ] && grep -q "spl_hostid=" ; then
	echo "Found ${old_hostid} in /etc/zfsbootmenu/config.yaml, updating"
  # TODO: do this via sed?
fi

# restore for easy test cycling right now
zfs set org.zfsbootmenu:commandline="${org_cmdline}" "${BE}"
umount "${MNT}"

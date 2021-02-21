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

if [ -n "${BE}" ]; then
  pool="${BE%%/*}"
  echo "Exporting pool: ${pool}"
  set_rw_pool "${pool}"
  export_pool "${pool}"
else
  echo "Please specify a boot environment!"
  exit 1
fi

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
if [ -n "${BE}" ]; then
  MNT="$( allow_rw=1 mount_zfs "${BE}" )"
  echo -ne "\\x${HOSTID:6:2}\\x${HOSTID:4:2}\\x${HOSTID:2:2}\\x${HOSTID:0:2}" > "${MNT}/etc/hostid"
  umount "${MNT}"
  BE_ARGS="$( load_be_cmdline "${BE}" )"
  echo "${BE_ARGS} spl_hostid=${HOSTID}" > "${BASE}/${BE}/cmdline"
fi


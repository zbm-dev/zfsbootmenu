#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

# shellcheck source=./zfsbootmenu-lib.sh 
[ -r /lib/zfsbootmenu-lib.sh ] && source /lib/zfsbootmenu-lib.sh

usage() {
  cat <<EOF
Usage: $0 [options]
  -h  8 digit hostid
  -b  Specific BE

By default, $0 operates on all discovered boot environments, with
a hostid of 00000000.
EOF
}

HOSTID="00000000"
BE=

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


echo "Setting SPL hostid to: ${HOSTID}"
echo "Setting hostid in ${BE}"

echo -ne "\\x${HOSTID:6:2}\\x${HOSTID:4:2}\\x${HOSTID:2:2}\\x${HOSTID:0:2}" > "/etc/hostid"

if [ -n "${BE}" ]; then
  pool="${BE%%/*}"
  echo "Exporting pool: ${pool}"
  export_pool "${pool}"
else
  while read -r pool ; do
    echo "Exporting pool: ${pool}"
    export_pool "${pool}"
  done <<<"$( zpool list -H -o name )"
fi

echo "Unloading ZFS and SPL kernel modules"
rmmod zfs
rmmod icp 
rmmod zzstd 
rmmod zcommon 
rmmod znvpair 
rmmod zavl
rmmod spl

modprobe zfs

read_write=1 all_pools=yes import_pool
populate_be_list "${BASE}/env" || rm -f "${BASE}/env"

if [ -n "${BE}" ]; then
  MNT="$( mount_zfs "${BE}" )"
  echo -ne "\\x${HOSTID:6:2}\\x${HOSTID:4:2}\\x${HOSTID:2:2}\\x${HOSTID:0:2}" > "${MNT}/etc/hostid"
  umount "${MNT}"
fi

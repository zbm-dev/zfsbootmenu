#!/bin/bash
reset
clear
$( zpool export -a > /dev/null )

OLDIFS="$IFS"

export FZF_DEFAULT_OPTS="--layout=reverse-list --cycle \
  --inline-info --tac"

BE_SELECTED=0
KERNEL_SELECTED=0

ENV_HEADER="[ALT+K] select kernel [ENTER] boot\n[ALT+A] all snapshots [ALT+S] BE snapshots"

## Functions to move to an include

underscore() {
  local bepath
  bepath="${1}"
  echo ${bepath} | sed 's,/,_,g'
}

slash() {
  local bepath
  bepath="${1}"
  echo ${bepath} | sed 's,_,/,g'
}

mount_zfs() {
  local fs mnt ret

  fs="${1}"
  mnt="${2}"

  test -d ${mnt} || return 1
  mount -o zfsutil -t zfs ${fs} ${mnt}
  ret=$?

  return ${ret}
}

umount_zfs() {
  local mnt ret

  mnt="${1}"
  umount ${mnt}
  ret=$?

  return ${ret}
}

# Master menu of detected boot environments
draw_be() {
  local env header selected ret

  env="${1}"
  header="${2}"

  test -f ${env} || return 130
  test -f ${header} || return 130

  selected="$( cat ${header} ${env} | fzf -0 --prompt "BE > " \
    --header-lines=2 --expect=alt-k,alt-s,alt-a,alt-r )"
  ret=$?
  while read -r line; do
    if [ -z "$line" ]; then
      line="enter"
    fi
    CSV+=("${line}")
  done <<< "${selected}"
  (IFS=',' ; printf '%s' "${CSV[*]}")
  return ${ret}
}

# Menu of kernels available in a specified boot environment
draw_kernel() {
  local benv pretty selected ret

  benv="${1}"

  # Set a pretty benv for our prompt
  pretty="$( slash ${benv})"
  pretty="${pretty#${BASE}/}"

  selected="$( cat ${benv} | fzf --prompt "${pretty} > " --tac \
    --with-nth=2 --header="[ENTER] boot
[ESC] back")"
  
  ret=$?
  echo ${selected}
  return ${ret}
}

# Menu of all snapshots, or optionally snapshots of a specific boot environment
draw_snapshots() {
  local benv selected ret

  benv="${1}"

  selected="$( zfs list -t snapshot -H -o name ${benv} | fzf --prompt "Snapshot > " --tac \
    --header="[ENTER] boot
[ESC] back" )"
  ret=$?
  echo ${selected}
  return ${ret}
}

kexec_kernel() {
  local selected fs kernel initramfs

  selected="${1}"

  clear

  # zfs filesystem
  # kernel
  # initramfs
  IFS=' ' read fs kernel initramfs <<<"${selected}"

  mount_zfs ${fs} ${BE}
  ret=$?
  if [ $ret != 0 ]; then
    emergency_shell "Unable to mount ${fs}"
  fi

  test -e ${BE}/etc/default/grub && . ${BE}/etc/default/grub
  kexec -l ${BE}${kernel} \
    --initrd=${BE}/${initramfs} \
    --command-line="root=zfs:${fs} ${GRUB_CMDLINE_LINUX_DEFAULT}"
  umount_zfs ${fs}
  zpool export -a
  kexec -e
}

kexec_snapshot() {
  local selected target response pairs last
  local kernel initramfs

  selected="${1}"
  IFS='@' read -a response <<<"${selected}"
  target="${response[0]}_clone"

  zfs clone -o mountpoint=/ \
    -o canmount=noauto \
    ${selected} ${target}

  mount_zfs ${target} ${BE}

  response="$( find_valid_kernels ${BE} )"
  IFS=',' read -a pairs <<<"${response}"
  last="${pairs[-1]}"
  IFS=';' read kernel initramfs <<<"${last}"

  kexec_kernel "${target} ${kernel} ${initramfs}"
}

# Return code is the number of kernels that can be used
find_valid_kernels() {
  local mnt
  mnt="${1}"

  local kernel version pairs
  pairs=()

  for kernel in $( ls ${mnt}/boot/vmlinux-* \
    ${mnt}/boot/vmlinuz-* \
    ${mnt}/boot/kernel-* \
    ${mnt}/boot/linux-* 2>/dev/null ); do
    
    kernel="${kernel#${mnt}}"
    version=$( echo $kernel | sed -e "s,^[^0-9]*-,,g" )

    for i in "initrd.img-${version}" "initrd-${version}.img" "initrd-${version}.gz" \
      "initrd-${version}" "initramfs-${version}.img"; do

      if test -e "${mnt}/boot/${i}" ; then
        pairs+=("${kernel};/boot/${i}")
        break
      fi
    done
  done

  # kernel1;initramfs1,kernel2;initramfs2,...
  (IFS=',' ; printf '%s' "${pairs[*]}")
  return "${#pairs[@]}"
}

# Return code is the number of pools that can be imported
find_online_pools() {
  local importable pool state junk
  importable=()
  while read -r line; do
    case "$line" in
      pool*)
        pool="${line#pool: }"
        ;;
      state*)
        state="${line#state: }"
        if [ "${state}" == "ONLINE" ]; then
          importable+=("${pool}")
        fi
        ;;
    esac
  done <<<"$( zpool import )"
  (IFS=',' ; printf '%s' "${importable[*]}")
  return "${#importable[@]}"
}

import_pool() {
  local pool
  pool="${1}"

  status=$( zpool import ${import_args} ${pool} )
  ret=$?

  return ${ret}
}

be_key_needed() {
  local fs pool encroot
  fs="${1}"
  pool="$( echo ${fs} | cut -d '/' -f 1 )"

  if [ $( zpool list -H -o feature@encryption ${pool}) == "active" ]; then
    encroot="$( zfs get -H -o value encryptionroot ${fs} )"
    if [ "${encroot}" == "-" ]; then
      echo ""
      return 0
    else
      echo "${encroot}"
      return 1
    fi
  else
    echo ""
    return 0
  fi
}

be_key_status() {
  local encroot keystatus
  encroot="${1}"

  keystatus="$( zfs get -H -o value keystatus ${encroot} )"
  case "${keystatus}" in
    unavailable)
      return 0;
      ;;
    available)
      return 1;
      ;;
  esac
}

load_key() {
  local encroot ret
  encroot="${1}"

  zfs load-key ${encroot}
  ret=$?

  return ${ret}
}

emergency_shell() {
  local message
  message=${1}
  echo "$0\n"
  echo -n "Launching emergency shell: "
  echo ${message}
  echo "Reboot after maintenance has been completed\n"
  /bin/bash
}
## End functions

BASE=$( mktemp -d /tmp/zfs.XXXX )
echo -e ${ENV_HEADER} > ${BASE}/env_header

BE="${BASE}/be"
mkdir ${BE}


# Find all pools by name that are listed as ONLINE, then import them
response="$( find_online_pools )"
ret=$?
if [ $ret -gt 0 ]; then
  IFS=',' read -a zpools <<<"${response}"
  for pool in "${zpools[@]}"; do
    import_pool ${pool}
    ret=$?
    if [ $ret -eq 0 ]; then
      import_success=1
    fi
  done
  if [ $import_success != 1 ]; then
    emergency_shell "unable to successfully import a pool"
  fi
else
  emergency_shell "unable to successfully import a pool"
fi

# Find our bootfs value, prefer a specific pool
# otherwise find the first available
if [ "${root}" = "zfsbootmenu" ]; then
  pool=
else
  pool="${root}"
fi

datasets="$( zpool list -H -o bootfs ${pool} )"
if [ -z "$datasets" ]; then
  BOOTFS=
else
  while read -r line; do
    BOOTFS="${line}"
    break
  done <<<"${datasets}"
fi

fast_boot=0
if [[ ! -z "${BOOTFS}" ]]; then
  IFS=''
  echo -e "[ENTER] to boot ${BOOTFS}\n[ESC] to access boot menu\n"
  for (( i=10; i>0; i--)); do
    printf "\rBooting in %0.2d seconds" $i
    read -s -N 1 -t 1 key
    if [ "$key" = $'\e' ]; then
      break
    elif [ "$key" = $'\x0a' ]; then
      fast_boot=1
      clear
      break
    fi
  done
  IFS="${OLDIFS}"
  
  # Boot up if we timed out, or if the enter key was pressed
  if [[ ${fast_boot} -eq 1 || $i -eq 0 ]]; then
    encroot="$( be_key_needed ${BOOTFS})"
    if [ $? -eq 1 ]; then
      if be_key_status ${encroot} ; then
        if ! load_key ${encroot} ; then
          emergency_shell "unable to load required key for ${encroot}"
        fi
      fi
    fi

    mount_zfs ${BOOTFS} ${BE}
    response="$( find_valid_kernels ${BE} )"
    IFS=',' read -a pairs <<<"${response}"
    last="${pairs[-1]}"
    IFS=';' read kernel initramfs <<<"${last}"
    umount_zfs ${BOOTFS}
    kexec_kernel "${BOOTFS} ${kernel} ${initramfs}"
  fi
fi

# Find any filesystems that mount to /, see if there are any kernels present
for fs in $( zfs list -H -o name,mountpoint | grep -E "/$" | cut -f1 ); do
  mount_zfs ${fs} ${BE}
  if [ ! -d ${BE}/boot ] ; then
    umount_zfs ${fs}
    continue
  fi
  
  sane="$( underscore ${fs} )"
  echo ${fs} >> ${BASE}/env

  response="$( find_valid_kernels ${BE} )"

  # Build array of kernel;initramfs pairs
  IFS=',' read -a pairs <<<"${response}"

  # Iterate over pairs and write: fs kernel initramfs to a flat file 
  for line in "${pairs[@]}"; do
    IFS=';' read kernel initramfs <<<"${line}"
    echo ${fs} ${kernel} ${initramfs} >> ${BASE}/${sane}
  done
  umount_zfs ${fs}
done

if [ ! -f ${BASE}/env ]; then
  emergency_shell "no boot environments with kernels found"
fi

while true; do
  if [ ${BE_SELECTED} -eq 0 ]; then
    bootenv="$( draw_be "${BASE}/env" "${BASE}/env_header")"
    ret=$?
    
    # key
    # bootenv
    IFS=, read key selected_be <<<"${bootenv}"

    if [ $ret -eq 0 ]; then
      BE_SELECTED=1
    fi
  fi

  if [ ${BE_SELECTED} -eq 1 ]; then
    case "${key}" in
      "enter")
        kexec_kernel "$( cat ${BASE}/$( underscore ${selected_be} ) | tail -n1 )"
        exit
        ;;
      "alt-k")
        selected_kernel="$( draw_kernel ${BASE}/$( underscore ${selected_be} ) )"
        ret=$?

        if [ $ret -eq 130 ]; then
          BE_SELECTED=0 
        elif [ $ret -eq 0 ] ; then
          kexec_kernel "${selected_kernel}"
          exit
        fi
        ;;
      "alt-s")
        selected_snap="$( draw_snapshots ${selected_be} )"
        ret=$?


        if [ $ret -eq 130 ]; then
          BE_SELECTED=0 
        elif [ $ret -eq 0 ] ; then
          kexec_snapshot "${selected_snap}"
          exit
        fi
        ;;
      "alt-a")
        selected_snap="$( draw_snapshots )"
        ret=$?

        if [ $ret -eq 130 ]; then
          BE_SELECTED=0 
        elif [ $ret -eq 0 ] ; then
          kexec_snapshot "${selected_snap}"
          exit
        fi
        ;;
      "alt-r")
        emergency_shell "alt-r invoked"
    esac
  fi
done

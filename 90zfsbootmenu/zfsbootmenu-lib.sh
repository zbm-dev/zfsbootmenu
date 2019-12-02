#!/bin/bash

# ZFS boot menu functions

# arg1: zroot/ROOT/bootenvironment
# prints: zroot_ROOT_bootenvironment
# returns: No return value

underscore() {
  local bepath
  bepath="${1}"
  echo ${bepath} | sed 's,/,_,g'
}

# arg1: zroot_ROOT_bootenvironment
# prints: zroot/ROOT/bootenvironment
# returns: No return value

slash() {
  local bepath
  bepath="${1}"
  echo ${bepath} | sed 's,_,/,g'
}

# arg1: ZFS filesystem name 
# arg2: mountpoint
# prints: No output
# returns: 0 on success 

mount_zfs() {
  local fs mnt ret

  fs="${1}"
  mnt="${2}"

  test -d ${mnt} || return 1
  mount -o zfsutil -t zfs ${fs} ${mnt}
  ret=$?

  return ${ret}
}

# arg1: mount point 
# prints: No output
# returns: 0 on success

umount_zfs() {
  local mnt ret

  mnt="${1}"
  umount ${mnt}
  ret=$?

  return ${ret}
}

# arg1: Path to file with header/options text
# arg2: Path to file with detected boot environments, 1 per line
# prints: key pressed, boot environment 
# returns: 130 on error, 0 otherwise

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

# arg1: ZFS filesystem name
# prints: bootfs, kernel, initramfs
# returns: 130 on error, 0 otherwise

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
  echo "${selected}"
  return ${ret}
}

# arg1: ZFS filesystem name
# prints: selected snapshot
# returns: 130 on error, 0 otherwise

draw_snapshots() {
  local benv selected ret

  benv="${1}"

  selected="$( zfs list -t snapshot -H -o name ${benv} | fzf --prompt "Snapshot > " --tac \
    --header="[ENTER] clone 
[ESC] back" )"
  ret=$?
  echo "${selected}"
  return ${ret}
}

# arg1: bootfs kernel initramfs
# prints: nothing
# returns: does not return

kexec_kernel() {
  local selected fs kernel initramfs

  selected="${1}"

  tput clear

  # zfs filesystem
  # kernel
  # initramfs
  IFS=' ' read fs kernel initramfs <<<"${selected}"

  mount_zfs ${fs} ${BASE_MOUNT}
  ret=$?
  if [ $ret != 0 ]; then
    emergency_shell "unable to mount ${fs}"
  fi

  test -e ${BASE_MOUNT}/etc/default/grub && . ${BASE_MOUNT}/etc/default/grub

  kexec -l ${BASE_MOUNT}${kernel} \
    --initrd=${BASE_MOUNT}/${initramfs} \
    --command-line="root=zfs:${fs} ${GRUB_CMDLINE_LINUX_DEFAULT}"

  umount_zfs ${fs}

  zpool export -a
  if ! [ $? -eq 0 ]; then
    emergency_shell "unable to export pools"
  fi

  kexec -e
}

# arg1: snapshot name
# prints: nothing
# returns: 0 on success

clone_snapshot() {
  local selected target response

  selected="${1}"
  IFS='@' read -a response <<<"${selected}"
  target="${response[0]}_${response[1]}"

  zfs clone -o mountpoint=/ \
    -o canmount=noauto \
    ${selected} ${target}
  ret=$?

  if [ $ret -eq 0 ]; then 
    if output=$( find_be_kernels "${target}" "${BASE_MOUNT}" ); then
      echo "${target}" >> ${BASE}/env
      return 0
    fi
  else
    return $ret 
  fi

}

# arg1: ZFS filesystem
# arg2: mountpoint
# prints: nothing
# returns: number of kernels found 

find_be_kernels() {
  local fs mnt 
  fs="${1}"
  mnt="${2}"

  local sane kernel version pairs
  pairs=()

  # Check if /boot even exists in the environment
  mount_zfs "${fs}" "${mnt}"
  if [ ! -d "${mnt}/boot" ]; then
    umount_zfs "${fs}"
    return
  fi

  # Create a filename with out /'s
  sane="$( underscore ${fs} )"

  # Remove this file if it already exists
  test -f ${BASE}/${sane} && rm ${BASE}/${sane}

  for kernel in $( ls ${mnt}/boot/vmlinux-* \
    ${mnt}/boot/vmlinuz-* \
    ${mnt}/boot/kernel-* \
    ${mnt}/boot/linux-* 2>/dev/null | sort -V ); do
    
    kernel="${kernel#${mnt}}"
    version=$( echo $kernel | sed -e "s,^[^0-9]*-,,g" )

    for i in "initrd.img-${version}" "initrd-${version}.img" "initrd-${version}.gz" \
      "initrd-${version}" "initramfs-${version}.img"; do

      if test -e "${mnt}/boot/${i}" ; then
        echo "${fs} ${kernel} /boot/${i}" >> ${BASE}/${sane}
        break
      fi
    done
  done

  umount_zfs "${fs}"

  # Return the number of kernels found 
  return "${#pairs[@]}"
}

# arg1: ZFS filesystem
# prints: fs kernel initramfs
# returns: nothing

select_kernel() {
  local fs
  fs="${1}"

  local sane specific_kernel kexec_args
  sane="$( underscore ${fs} )"
  
  specific_kernel="$( zfs get -H -o value org.zfsbootmenu:kernel ${BOOTFS} )"
  # No value set, pick the last kernel entry
  if [ "${specific_kernel}" = "-" ]; then
    kexec_args="$( tail -1 ${BASE}/${sane} )"
  else
    while read -r kexec_args; do
      local fs kernel initramfs
      IFS=' ' read fs kernel initramfs <<<"${kexec_args}"
      if [[ "${kernel}" =~ "${specific_kernel}" ]]; then
        break
      fi
    done <<<"$( cat ${BASE}/${sane} )"
  fi

  echo "${kexec_args}"
}

# no arguments
# prints: nothing
# returns: number of pools that can be imported

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

# arg1: pool name
# prints: nothing
# returns: 0 on success, 1 on failure

import_pool() {
  local pool
  pool="${1}"

  status=$( zpool import ${import_args} ${pool} )
  ret=$?

  return ${ret}
}

# arg1: ZFS filesystem
# prints: name of encryption root, if present
# returns: 1 if key is needed, 0 if not

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

# arg1: ZFS filesystem (encryption root)
# prints: nothing
# returns: 0 if unavailable, 1 if available

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

# arg1: ZFS filesystem (encryption root)
# prints: nothing
# returns: 0 on success, 1 on failure

load_key() {
  local encroot ret key keyformat keylocation
  encroot="${1}"
  tput clear
  tput cup 0 0

  keylocation="$( zfs get -H -o value keylocation ${encroot} )"
  if [ "${keylocation}" = "prompt" ]; then
    zfs load-key -L prompt ${encroot}
    ret=$?
  else
    key="${keylocation#file://}"
    keyformat="$( zfs get -H -o value keyformat ${encroot} )"
    if [[ -f "${key}" ]]; then
      zfs load-key ${encroot}
      ret=$?
    elif [ "${keyformat}" = "passphrase" ]; then
      zfs load-key -L prompt ${encroot}
      ret=$?
    fi
  fi

  return ${ret}
}

# arg1: message
# prints: nothing
# returns: nothing

emergency_shell() {
  local message
  message=${1}
  echo -n "Launching emergency shell: "
  echo -e "${message}\n"
  /bin/bash
}

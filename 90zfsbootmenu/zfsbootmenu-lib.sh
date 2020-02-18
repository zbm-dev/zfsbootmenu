#!/bin/bash

# ZFS boot menu functions

# arg1: ZFS filesystem name 
# arg2: mountpoint
# prints: No output
# returns: 0 on success 

mount_zfs() {
  local fs mnt ret

  fs="${1}"

  mnt="${BASE}/${fs}/mnt"
  test -d "${mnt}" || mkdir -p "${mnt}"

  mount -o zfsutil -t zfs "${fs}" "${mnt}"
  ret=$?

  echo "${mnt}"
  return ${ret}
}

# arg1: Path to file with detected boot environments, 1 per line
# prints: key pressed, boot environment 
# returns: 130 on error, 0 otherwise

draw_be() {
  local env header selected ret

  env="${1}"

  test -f ${env} || return 130

  selected="$( cat ${env} | fzf -0 --prompt "BE > " \
    --expect=alt-k,alt-s,alt-a,alt-r,alt-d \
    --preview-window=up:2 \
    --header="[ENTER] boot [ALT+K] kernel [ALT+D] set bootfs [ALT+S] snapshots" \
    --preview="zfsbootmenu-preview.sh ${BASE} {} ${BOOTFS}")"
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

  selected="$( cat ${BASE}/${benv}/kernels | fzf --prompt "${benv} > " --tac \
    --with-nth=2 --header="[ENTER] boot [ESC] back")"
  
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
    --header="[ENTER] clone [ESC] back" )"
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

  mnt="$( mount_zfs "${fs}" )"

  ret=$?
  if [ $ret != 0 ]; then
    emergency_shell "unable to mount ${fs}"
  fi

  while IFS= read -r line
  do
    cli_args="${line}"
  done < "${BASE}/${fs}/default_args"

  # restore kernel log level just before we kexec
  echo "${printk}" > /proc/sys/kernel/printk

  kexec -l "${mnt}${kernel}" \
    --initrd="${mnt}${initramfs}" \
    --command-line="root=zfs:${fs} ${cli_args}"

  umount ${mnt}

  # Export if read-write, to ensure a clean pool
  pool="${selected%%/*}"
  if [ "$( zpool get -H -o value readonly "${pool}" )" = "off" ]; then
    export_pool "${pool}"
  fi
  
  kexec -e -i
}

# arg1: snapshot name
# prints: nothing
# returns: 0 on success

clone_snapshot() {
  local selected target response

  selected="${1}"

  pool="${selected%%/*}"

  # If the pool is read-only, flip the arg off then export and import
  if [ "$( zpool get -H -o value readonly "${pool}" )" = "on" ]; then
    export_pool "${pool}"
    import_args="${import_args/readonly=on/readonly=off}"
    import_pool "${pool}"
  fi

  target="${selected/@/_}"

  if $( zfs list -H -o name | grep -q "${target}" ); then
    last_env="$( zfs list -H -o name | grep "${target}" | tail -1 )"
    index="${last_env##${target}_}"
    index="$(( ${index} + 1 ))"
  else
    index="0"
  fi

  target="$( printf "%s_%0.3d" "${target}" "${index}" )"

  zfs clone -o mountpoint=/ \
    -o canmount=noauto \
    "${selected}" "${target}"
  ret=$?

  if [ $ret -eq 0 ]; then 
    key_wrapper "${target}"
    if [ $? -eq 0 ]; then
      if output=$( find_be_kernels "${target}" ); then
        echo "${target}" >> "${BASE}/env"
        return 0
      else
        # No kernels were found
        return 1
      fi
    else
      # keys were needed, but not loaded
      return 1
    fi
  else
    # Clone failed
    return $ret 
  fi
}

set_default_env() {
  local selected
  selected="${1}"

  pool="${selected%%/*}"

  # If the pool is read-only, flip the arg off then export and import
  if [ "$( zpool get -H -o value readonly "${pool}" )" = "on" ]; then
    export_pool "${pool}"
    import_args="${import_args/readonly=on/readonly=off}"
    import_pool "${pool}"
    key_wrapper "${pool}"
  fi

  if output="$( zpool set bootfs="${selected}" "${pool}" )"; then
    BOOTFS="${selected}"
  fi
}

# arg1: ZFS filesystem
# arg2: mountpoint
# prints: nothing
# returns: 0 if kernels were found

find_be_kernels() {
  local fs mnt 
  fs="${1}"


  local sane kernel version kernel_records

  # Check if /boot even exists in the environment
  mnt="$( mount_zfs "${fs}" )"
  kernel_records="${mnt/mnt/kernels}"

  if [ ! -d "${mnt}/boot" ]; then
    umount "${mnt}"
    return 1
  fi

  for kernel in $( ls ${mnt}/boot/vmlinux-* \
    ${mnt}/boot/vmlinuz-* \
    ${mnt}/boot/kernel-* \
    ${mnt}/boot/linux-* 2>/dev/null | sort -V ); do
    
    kernel="${kernel#${mnt}}"
    version=$( echo $kernel | sed -e "s,^[^0-9]*-,,g" )

    for i in "initrd.img-${version}" "initrd-${version}.img" "initrd-${version}.gz" \
      "initrd-${version}" "initramfs-${version}.img"; do

      if test -e "${mnt}/boot/${i}" ; then
        echo "${fs} ${kernel} /boot/${i}" >> "${kernel_records}"
        break
      fi
    done
  done

  defaults="$( select_kernel "${fs}" )"
  IFS=' ' read def_fs def_kernel def_initramfs <<<"${defaults}"
  def_kernel="$( basename "${def_kernel}" )"
  def_version=$( echo $def_kernel | sed -e "s,^[^0-9]*-,,g" )

  def_kernel_file="${mnt/mnt/default_kernel}"
  echo "${def_version}" > "${def_kernel_file}"

  def_args="$( find_kernel_args "${mnt}" )"
  def_args_file="${mnt/mnt/default_args}"
  echo "${def_args}" > "${def_args_file}"

  umount "${mnt}"
  return 0
}

# arg1: ZFS filesystem
# prints: fs kernel initramfs
# returns: nothing

select_kernel() {
  local zfsbe
  zfsbe="${1}"

  local sane specific_kernel kexec_args
  
  specific_kernel="$( zfs get -H -o value org.zfsbootmenu:kernel ${zfsbe} )"

  # No value set, pick the last kernel entry
  if [ "${specific_kernel}" = "-" ]; then
    kexec_args="$( tail -1 ${BASE}/${zfsbe}/kernels )"
  else
    while read -r kexec_args; do
      local fs kernel initramfs
      IFS=' ' read fs kernel initramfs <<<"${kexec_args}"
      if [[ "${kernel}" =~ "${specific_kernel}" ]]; then
        break
      fi
    done <<<"$( tac ${BASE}/${zfsbe}/kernels )"
  fi

  echo "${kexec_args}"
}

find_kernel_args() {
  local zfsbe
  zfsbe="${1}"

  local arguments

  if [ -f "${zfsbe}/etc/default/grub" ]; then
    echo "$(
      . "${zfsbe}/etc/default/grub" ;
      echo "${GRUB_CMDLINE_LINUX_DEFAULT}"
    )"
    return
  fi

  # No arguments found, return something generic
  echo "quiet loglevel=3"
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

  status="$( zpool import ${import_args} ${pool} )"
  ret=$?

  return ${ret}
}

# arg1: pool name
# prints: nothing
# returns: 0 on success, 1 on failure

export_pool() {
  local pool
  pool="${1}"

  status="$( zpool export ${pool} )"
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

  keylocation="$( zfs get -H -o value keylocation ${encroot} )"
  if [ "${keylocation}" = "prompt" ]; then
    tput clear
    tput cup 0 0
    zfs load-key -L prompt ${encroot}
    ret=$?
  else
    key="${keylocation#file://}"
    keyformat="$( zfs get -H -o value keyformat ${encroot} )"
    if [[ -f "${key}" ]]; then
      zfs load-key ${encroot}
      ret=$?
    elif [ "${keyformat}" = "passphrase" ]; then
      tput clear
      tput cup 0 0
      zfs load-key -L prompt ${encroot}
      ret=$?
    fi
  fi

  return ${ret}
}

# arg1: ZFS filesystem
# prints: nothing
# returns 0 on success, 1 on failure

key_wrapper() {
  local encroot fs ret
  fs="${1}"
  ret=0

  encroot="$( be_key_needed ${fs})"

  if [ $? -eq 1 ]; then
    if be_key_status ${encroot} ; then
      if ! load_key ${encroot} ; then
        ret=1
      fi
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

#!/usr/bin/bash

export FZF_DEFAULT_OPTS="--layout=reverse-list --cycle \
  --inline-info --tac --no-clear"

BE_SELECTED=0
KERNEL_SELECTED=0

ENV_HEADER="[ALT+K] select kernel [ENTER] boot\n[ALT+A] all snapshots [ALT+S] BE snapshots"

## Functions to move to an include

underscore() {
  bepath="${1}"
  echo ${bepath} | sed 's,/,_,g'
}

slash() {
  bepath="${1}"
  echo ${bepath} | sed 's,_,/,g'
}

# Master menu of detected boot environments
draw_be() {
  env="${1}"
  selected="$( cat ${env} | fzf --prompt "BE > " \
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
  benv="${1}"
  selected="$( zfs list -t snapshot -H -o name ${benv} | fzf --prompt "Snapshot > " --tac \
    --header="[ENTER] boot
[ESC] back" )"
  ret=$?
  echo ${selected}
  return ${ret}
}

kexec_kernel() {
  selected="${1}"

  # zfs filesystem
  # kernel
  # initramfs
  IFS=' ' read -a response <<<"${selected}"

  zfs mount ${response[0]}
  test -e ${BE}/etc/default/grub && . ${BE}/etc/default/grub
  kexec -l ${BE}${response[1]} \
    --initrd=${BE}/${response[2]} \
    --command-line="root=zfs:${response[1]} ${GRUB_CMDLINE_LINUX_DEFAULT}"
  zfs umount ${response[0]}
  zpool export -a
  kexec -e
}

kexec_snapshot() {
  selected="${1}"
  echo "Promoting snapshot: ${selected}"
  zpool export -a
  exit
}

## End functions

BASE=$( mktemp -d /tmp/zfs.XXXX )

BE="${BASE}/be"
mkdir ${BE}

# Import all pools with a temporary mountpoint sent to ${BE}
zpool import -N -a -R ${BE}

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
  done <<< "${datasets}"
fi

echo -e ${ENV_HEADER} > ${BASE}/env  

for fs in $( zfs list -H -o name,mountpoint | grep -E "${BE}$" | cut -f1 ); do
  zfs mount ${fs}
  if [ ! -d ${BE}/boot ] ; then
    zfs umount ${fs}
    continue
  fi

  sane="$( underscore ${fs} )"
  echo ${fs} >> ${BASE}/env

  for kernel in $( ls ${BE}/boot/vmlinux-* ); do
    kernel="${kernel#${BE}}"
    version=$( echo $kernel | sed -e "s,^[^0-9]*-,,g" )
    for i in "initrd.img-${version}" "initrd-${version}.img" "initrd-${version}.gz" \
      "initrd-${version}" "initramfs-${version}.img"; do
      
      if test -e "${BE}/boot/${i}" ; then
        initramfs="/boot/${i}"
        echo "${fs} ${kernel} ${initramfs}" >> ${BASE}/${sane}
        break
      fi
    done
  done
  zfs umount ${fs}
done

while true; do
  if [ ${BE_SELECTED} -eq 0 ]; then
    bootenv="$( draw_be "${BASE}/env" )"
    ret=$?
    
    # key
    # bootenv
    IFS=, read -a response <<<"${bootenv}"
    
    if [ $ret -eq 0 ]; then
      BE_SELECTED=1
    fi
  fi

  if [ ${BE_SELECTED} -eq 1 ]; then
    case "${response[0]}" in
      "enter")
        kexec_kernel "$( cat ${BASE}/$( underscore ${response[1]} ) | tail -n1 )"
        exit
        ;;
      "alt-k")
        selected="$( draw_kernel ${BASE}/$( underscore ${response[1]} ) )"
        ret=$?

        if [ $ret -eq 130 ]; then
          BE_SELECTED=0 
        elif [ $ret -eq 0 ] ; then
          kexec_kernel "${selected}"
          exit
        fi
        ;;
      "alt-s")
        selected="$( draw_snapshots ${response[1]} )"
        ret=$?


        if [ $ret -eq 130 ]; then
          BE_SELECTED=0 
        elif [ $ret -eq 0 ] ; then
          kexec_snapshot "${selected}"
          exit
        fi
        ;;
      "alt-a")
        selected="$( draw_snapshots )"
        ret=$?

        if [ $ret -eq 130 ]; then
          BE_SELECTED=0 
        elif [ $ret -eq 0 ] ; then
          kexec_snapshot "${selected}"
          exit
        fi
        ;;
      "alt-r")
        echo "Entering recovery shell"
        exit
    esac
  fi
done

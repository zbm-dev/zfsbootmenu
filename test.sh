#!/usr/bin/bash

export FZF_DEFAULT_OPTS="--layout=reverse-list --cycle \
  --inline-info --tac --no-clear"

OLDIFS="${IFS}"
NEWLINE="
"

BE_SELECTED=0
KERNEL_SELECTED=0

ENV_HEADER="[ENTER] to boot\n[ALT+K] to select kernel\n[ALT+S] to select snapshot"

## Functions to move to an include
draw_be() {
  env="${1}"
  selected="$( cat ${env} | fzf --prompt "BE > " \
    --header-lines=3 --expect=alt-k,alt-s )"
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

draw_kernel() {
  benv="${1}"
  selected="$( cat ${benv} | fzf --prompt "Kernel > " --tac \
    --header="[Enter] to boot" --with-nth=2)"
  ret=$?
  echo ${selected}
  return ${ret}
}

kexec_kernel() {
  selected="${1}"
  zfs=$( echo ${selected} | cut -d ' ' -f 1 )
  kernel=$( echo ${selected} | cut -d ' ' -f 2 )
  initramfs=$( echo ${selected} | cut -d ' ' -f 3 )

  zfs mount ${zfs}
  test -e ${BE}/etc/default/grub && . ${BE}/etc/default/grub
  echo kexec -l ${BE}/boot/${kernel} \
    --initrd=${BE}/${initramfs} \
    --command-line="root=zfs:${zfs} ${GRUB_CMDLINE_LINUX_DEFAULT}"
  zfs umount ${zfs}
  zpool export -a
  exit
}

## End functions

BASE=$( mktemp -d /tmp/zfs.XXXX )

BE="${BASE}/be"
mkdir ${BE}

SNAP="${BASE}/snap"
mkdir ${SNAP}

# Import all pools with a temporary mountpoint sent to ${BE}
zpool import -f -N -a -R ${BE}

# Find our bootfs value, prefer a specific pool
# otherwise find the first available
if [ "${root}" = "zfsbootmenu" ]; then
  pool=
else
  pool="${root}"
fi

datasets="$( zpool list -H -o bootfs ${pool} )"
if [ -z "$dataset" ]; then
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

  sane=$( echo ${fs} | sed 's,/,_,g' )
  echo ${fs} >> ${BASE}/env

  for kernel in $( ls ${BE}/boot/vmlinux-* ); do
    kernel="${kernel#${BE}}"
    version=$( echo $kernel | sed -e "s,^[^0-9]*-,,g" )
    for i in "initrd.img-${version}" "initrd-${version}.img" "initrd-${version}.gz" \
      "initrd-${version}" "initramfs-${version}.img"; do
      
      if test -e "${BE}/boot/${i}" ; then
        initramfs="${i}"
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
    
    method="$( echo ${bootenv} | cut -d , -f 1 )"
    bootenv="$( echo ${bootenv} | cut -d , -f 2 )"
    sane=$( echo ${bootenv} | sed 's,/,_,g' )

    if [ $ret -eq 0 ]; then
      BE_SELECTED=1
    fi
  fi

  if [ ${BE_SELECTED} -eq 1 ]; then
    case "${method}" in
      "enter")
        kexec_kernel "$( cat ${BASE}/${sane} | tail -n1 )"
        exit
        ;;
      "alt-k")
        selected="$( draw_kernel ${BASE}/${sane} )"
        ret=$?

        if [ $ret -eq 130 ]; then
          BE_SELECTED=0 
        elif [ $ret -eq 0 ] ; then
          kexec_kernel "${selected}"
        fi
        ;;
      "alt-s")
        clear
        echo "We need to select a snapshot"
        exit
        ;;
    esac
  fi
done

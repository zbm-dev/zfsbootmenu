#!/bin/sh
set -e

MNT=$( mktemp -d /tmp/XXXXXX )
test -f /tmp/boot-menu && rm /tmp/boot-menu

zpool import -f -N -a -R ${MNT}

for fs in $( zfs list -H -o name,mountpoint | grep -E "${MNT}$" | cut -f1 ); do
    zfs mount ${fs}
    if [ ! -d ${MNT}/boot ] ; then
        zfs umount ${fs}
        continue
    fi
    test -e ${MNT}/etc/default/grub && . ${MNT}/etc/default/grub
    for kernel in $( ls ${MNT}/boot/vmlinux-* ${MNT}/boot/vmlinuz-* ${MNT}/boot/kernel-* | xargs -n1 basename ); do
        version=$( echo $kernel | sed -e "s,^[^0-9]*-,,g" )
        for i in "initrd.img-${version}" "initrd-${version}.img" "initrd-${version}.gz" \
            "initrd-${version}" "initramfs-${version}.img"; do
            if test -e "${MNT}/boot/${i}" ; then
                initramfs="${i}"
                echo "${fs} ${kernel} ${initramfs} ${GRUB_CMDLINE_LINUX_DEFAULT}" >> /tmp/boot-menu
                break
            fi
        done
    done
    zfs umount ${fs}
done
test -f /tmp/boot-menu || /bin/sh

reset
clear

boot=$( cat /tmp/boot-menu | sort -nr | fzf --with-nth=1,2 --header "Select kernel" --layout=reverse-list --cycle )

zfs=$( echo $boot | cut -d ' ' -f1 )
kernel=$( echo $boot | cut -d ' ' -f2 )
initramfs=$( echo $boot | cut -d ' ' -f3 )
cmdline=$( echo $boot | cut -d ' ' -f4- )

zfs mount $zfs

kexec -l ${MNT}/boot/${kernel} --initrd ${MNT}/boot/${initramfs} --command-line=\"root=zfs:${zfs} ${cmdline}\"

zfs umount $zfs

zpool export -a

kexec -e

#!/bin/bash

# shellcheck disable=SC1091
[ -f /lib/zfsbootmenu-lib.sh ] && source /lib/zfsbootmenu-lib.sh

if [ $# -ne 3 ] ; then
 echo "Usage: $0 filesystem kernel initramfs"
 exit
fi

fs="${1}"
kernel="/boot/${2}"
initramfs="/boot/${3}"

kexec_kernel "${fs} ${kernel} ${initramfs}"

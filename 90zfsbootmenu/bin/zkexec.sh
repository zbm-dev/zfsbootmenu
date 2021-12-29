#!/bin/bash

# shellcheck disable=SC1091
source /lib/kmsg-log-lib.sh >/dev/null 2>&1 || exit 1
source /lib/zfsbootmenu-lib.sh >/dev/null 2>&1 || exit 1

if [ $# -ne 3 ] ; then
 echo "Usage: $0 filesystem kernel initramfs"
 exit
fi

fs="${1}"
kernel="/boot/${2}"
initramfs="/boot/${3}"

kexec_kernel "${fs} ${kernel} ${initramfs}"

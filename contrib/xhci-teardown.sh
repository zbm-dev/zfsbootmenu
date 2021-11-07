#!/bin/sh

## Some XHCI USB controllers, like on a 2015 MacBook Air, will not be properly
## reinitialized after ZFSBootMenu jumps into the system kernel with kexec; no
## USB devices will be enumerated, so e.g., keyboards will not function.
##
## One way to work around this is to just blacklist USB modules in ZFSBootMenu,
## but this prevents keyboard interaction in the boot menu. A better
## alternative is to try unbinding all USB controllers from xhci_hcd
## immediately before jumping into the new kernel, which allows the new kernel
## to properly initialize the USB subsystem.
##
## This could be adapted to other drivers, including {O,U,E}HCI as necessary.
##
## To use, put this script somewhere, make sure it is executable, and add the
## path to the `zfsbootmenu_teardown` space-separated list with, e.g.,
##
##     zfsbootmenu_teardown+=" <path to script> "
##
## in a dracut.conf(5) file inside the directory specified for the option
## `Global.DracutConfDir` in the ZFSBootMenu `config.yaml`.

SYS_XHCI=/sys/bus/pci/drivers/xhci_hcd

# shellcheck disable=SC2231
for DEVPATH in ${SYS_XHCI}/????:??:??.?; do
	[ -L "${DEVPATH}" ] || continue
	DEVICE="${DEVPATH#"${SYS_XHCI}"/}"
	echo "Tearing down USB controller ${DEVICE}..."
	echo "${DEVICE}" > ${SYS_XHCI}/unbind
done

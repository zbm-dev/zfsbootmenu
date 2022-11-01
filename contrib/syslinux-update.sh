#!/bin/bash

## This script can be used by generate-zbm to update a syslinux configuration
## after a ZFSBootMenu initramfs and kernel pair is created. The file system
## from which syslinux will run, which can be ext2/3/4 (make sure to disable
## the `64bit` feature), NTFS, UFS/FFS, XFS or btrfs, must be mounted when this
## hook runs. To ensure that syslinux can find the ZFSBootMenu kernel and
## initramfs, make sure to set the `Components.ImageDir` option in your
## ZFSBootMenu configuration to a path within the syslinux file system.
##
## Ensure the file is executable and place it in the directory specified by the
## `Global.PostHooksDir` option in your ZFSBootMenu configuration file.
##
## This script uses the SYSLINUX_ROOT to refer to the mount point of the
## syslinux filesystem and KERNEL_PATH to be the subdirectory, relative to
## SYSLINUX_ROOT, where ZFSBootMenu will install initramfs and kernel pairs.
## Kernels are expected to have file names of the form
##
##     ${KERNEL_PREFIX}[-<version>]
##
## and a corresponding initramfs image
##
##     initramfs[-<version>].img
##
## When creating syslinux entries, the variable ZBM_KCL_ARGS defines the
## command-line arguments that will be passed to each ZFSBootMenu kernel.
##
## Customized headers and entries can be added before any automatic entries by
## creating a directory and dumping syslinux configuration snippets to it. The
## location of this directory is defined by the SYSLINUX_CONFD variable.
##
## Change the above variables as necessary to reflect your configuration.

## By default, syslinux is on /boot/syslinux
SYSLINUX_ROOT="/boot/syslinux"
## By default, kernel and initramfs pairs will be in /boot/syslinux/zbm
KERNEL_PATH="zbm"
## By default, kernels are files starting with "vmlinuz"
KERNEL_PREFIX="vmlinuz"

# Set to a directory containing configuration snippets, if desired
SYSLINUX_CONFD=""

# By default, no arguments are passed to the kernel
ZBM_KCL_ARGS=""

if [ ! -d "${SYSLINUX_ROOT}" ]; then
	echo "ERROR: syslinux root '${SYSLINUX_ROOT}' does not exist"
	exit 1
fi

KERNEL_DIR="${SYSLINUX_ROOT}/${KERNEL_PATH}"
KERNEL_DIR="${KERNEL_DIR%/}"
if [ ! -d "${KERNEL_DIR}" ]; then
	echo "ERROR: kernel path '${KERNEL_DIR}' does not exist"
	exit 1
fi

SYSLINUX_CFG=
cleanup() {
	[ -n "${SYSLINUX_CFG}" ] && rm -f "${SYSLINUX_CFG}"
	unset SYSLINUX_CFG
}

trap cleanup EXIT INT TERM QUIT

if ! SYSLINUX_CFG="$(mktemp)"; then
	echo "ERROR: failed to make a temporary syslinux.cfg"
	exit 1
fi

# Populate the header with configuration snippets
FOUND_SNIPPETS=
if [ -d "${SYSLINUX_CONFD}" ]; then
	readarray -t SNIPPETS < <(printf '%s\n' "${SYSLINUX_CONFD}"/* | sort)
	for snip in "${SNIPPETS[@]}"; do
		[ -r "${snip}" ] || continue

		FOUND_SNIPPETS="yes"
		cat < "${snip}" >> "${SYSLINUX_CFG}"
	done
fi

# Use a default header if no configuration snippets are defined
if [ -z "${FOUND_SNIPPETS}" ]; then
	# Write the standard configuration header
	cat > "${SYSLINUX_CFG}" <<-EOF
	UI menu.c32
	PROMPT 0

	MENU TITLE Choose a ZFSBootMenu image to boot
	TIMEOUT 50
	EOF
fi

# Sort list of candidate kernels by version, newest first
readarray -t KERNELS < <(printf '%s\n' "${KERNEL_DIR}/${KERNEL_PREFIX}"* | sort -V -r)

# Identify each kernel/initramfs pair
# The first in sort order will be the default
DEFAULT_SET=
for kern in "${KERNELS[@]}"; do
	# Make sure file exists and strip leading path
	[ -f "${kern}" ] || continue
	kern="${kern##*/}"

	# Strip the kernel prefix to look for matching initramfs
	version="${kern#"${KERNEL_PREFIX}"}"
	initramfs="initramfs${version}.img"
	[ -f "${KERNEL_DIR}/${initramfs}" ] || continue

	zbmlabel="zfsbootmenu${version//[[:space:]]/}"

	if [ -z "${DEFAULT_SET}" ]; then
		echo "DEFAULT ${zbmlabel}" >> "${SYSLINUX_CFG}"
		DEFAULT_SET="yes"
	fi

	cat >> "${SYSLINUX_CFG}" <<-EOF

	LABEL ${zbmlabel}
	MENU LABEL ZFSBootMenu (${version#-})
	LINUX ${KERNEL_PATH:+/${KERNEL_PATH}}/${kern}
	INITRD ${KERNEL_PATH:+/${KERNEL_PATH}}/${initramfs}
	EOF

	if [ -n "${ZBM_KCL_ARGS}" ]; then
		echo "APPEND ${ZBM_KCL_ARGS}" >> "${SYSLINUX_CFG}"
	fi
done

if [ -z "${DEFAULT_SET}" ]; then
	echo "ERROR: failed to find any kernels"
	exit 1
fi

cp "${SYSLINUX_CFG}" "${SYSLINUX_ROOT}/syslinux.cfg"

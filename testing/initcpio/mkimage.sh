#!/bin/bash

error() {
	echo "ERROR: $*" >&2
	exit 1
}

usage() {
	cat <<-EOF
	USAGE: $0 [OPTIONS]

	  Build an initramfs image capable of creating ZBM testbeds

	OPTIONS

	-h
	   Display this message and exit

	-k <kernel>
	   Specify a particular kernel to use

	-c
	   Remove kernel and initramfs
	EOF
}

version_for_kernel() {
	local kfile kver kpat

	kfile="${1}"
	[ -r "${kfile}" ] || error "kernel file does not exist"

	kpat="^[0-9]\+\.[0-9]\+\.[0-9]\+\S\+"
	kver="$(strings "${kfile}" | grep -o -m 1 "${kpat}")" || kver=
	[ -n "${kver}" ] || error "failed to determine version for kernel"

	echo "${kver}"
	return 0
}

pick_kernel() {
	local kpath

	while read -r kpath; do
		[ -r "${kpath}" ] || continue;
		echo "${kpath}"
		return 0
	done <<< "$(echo /boot/vmlinuz* | xargs printf '%s\n' | sort -Vr)"

	error "failed to find a usable kernel"
}

create_image() {
	local mconf kver

	kver="${1}"
	[ -n "${kver}" ] || error "a kernel version is required"

	command -v mkinitcpio >/dev/null 2>&1 || error "mkinitcpio is not in path"
	[ -d /usr/lib/initcpio ] || error "path /usr/lib/initcpio does not exist"

	mconf="./mkinitcpio.conf"
	[ -r "${mconf}" ] || error "local mkinitcpio.conf does not exist"

	mkinitcpio -D . -D /usr/lib/initcpio \
		-k "${kver}" -c "${mconf}" -g "./zbm-test.img"
}

kpath=
clean=
while getopts "ck:h" opt; do
	case "${opt}" in
		c)
			clean="yes"
			;;
		k)
			kpath="${OPTARG}"
			;;
		h)
			usage
			exit 0
			;;
		*)
			usage
			exit 1
			;;
	esac
done

# Find the directory containing this script and move to it
if [ "${clean}" = "yes" ]; then
	echo "Removing existing zbm-test kernel and initramfs"
	rm -f zbm-test.img zbm-test.kernel
	exit
fi


[ -n "${kpath}" ] || kpath="$(pick_kernel)"

kver="$(version_for_kernel "${kpath}")"

echo "Creating image for kernel '${kpath}' (version ${kver})"

create_image "${kver}"
cp "${kpath}" zbm-test.kernel

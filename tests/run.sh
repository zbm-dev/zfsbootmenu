#!/bin/bash

# Setup a local config file
if [ ! -f local.yaml ]; then 
  cp ../etc/zfsbootmenu/config.yaml local.yaml
  yq-go w -i local.yaml Components.ImageDir "$( pwd )"
  yq-go w -i local.yaml Components.Versions false
  yq-go w -i local.yaml Global.ManageImages true 
  yq-go d -i local.yaml Global.BootMountPoint
fi

# Support x86_64 and ppc64(le)
case "$(uname -m)" in
  ppc64*)
    BIN="qemu-system-ppc64"
    KERNEL="vmlinux-bootmenu"
    MACHINE="pseries,accel=kvm,kvm-type=HV,cap-hpt-max-page-size=4096"
  ;;
  x86_64)
    BIN="qemu-system-x86_64"
    KERNEL="vmlinuz-bootmenu"
    MACHINE="type=q35,accel=kvm"
  ;;
esac

DRIVE="format=raw,file=zfsbootmenu-pool.img"
INITRD="initramfs-bootmenu.img"
MEMORY="2048M"
SMP="2"
DISPLAY="gtk"
APPEND="loglevel=7 timeout=5 zfsbotmenu:POOL=ztest"

# Override any default variables
#shellcheck disable=SC1091
[ -f .config ] && source .config

while getopts "a:" opt; do
  case "${opt}" in
    a)
      APPEND="${OPTARG}"
      ;;
    *)
      ;;
  esac
done

# Purge kernel/initramfs from the previous run
[ -f "${KERNEL}" ] && rm "${KERNEL}"
[ -f "${INITRD}" ] && rm "${INITRD}"

# Generate a new initramfs
../bin/generate-zbm -c local.yaml

# Boot it up
"${BIN}" \
	-kernel "${KERNEL}" \
	-initrd "${INITRD}" \
	-drive "${DRIVE}" \
	-m "${MEMORY}" \
	-smp "${SMP}" \
	-cpu host \
	-machine "${MACHINE}" \
	-object rng-random,id=rng0,filename=/dev/urandom \
	-device virtio-rng-pci,rng=rng0 \
	-display "${DISPLAY}" \
	-append "${APPEND}"

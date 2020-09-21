#!/bin/bash

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
NOCREATE=0

# Override any default variables
#shellcheck disable=SC1091
[ -f .config ] && source .config

while getopts "a:n" opt; do
  case "${opt}" in
    a)
      APPEND="${OPTARG}"
      ;;
    n)
      NOCREATE=1
      ;;
    *)
      ;;
  esac
done

if ((NOCREATE)) ; then
  # Don't create anything
  [ -f "${KERNEL}" ] || echo "Missing kernel: ${KERNEL}" && exit
  [ -f "${INITRD}" ] || echo "Missing initramfs: ${INITRD}" && exit
else
  # Create our initramfs
  [ -f "${KERNEL}" ] && rm "${KERNEL}"
  [ -f "${INITRD}" ] && rm "${INITRD}"
  #shellcheck disable=SC2164
  cd modules.d
  ../../bin/generate-zbm -c ../local.yaml
fi

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
	-append "${APPEND}" > /dev/null 2>&1

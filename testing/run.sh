#!/bin/bash
usage() {
  cat <<EOF
Usage: $0 [options]
  -a  Set kernel command line
  -n  Do not recreate the initramfs
EOF
}

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
DISPLAY_TYPE="gtk"
APPEND="loglevel=7 timeout=5 zfsbootmenu:POOL=ztest"
CREATE=1

# Override any default variables
#shellcheck disable=SC1091
[ -f .config ] && source .config

while getopts "a:nh" opt; do
  case "${opt}" in
    a)
      APPEND="${OPTARG}"
      ;;
    n)
      CREATE=0
      ;;
    \?|h)
      usage
      exit
      ;;
    *)
      ;;
  esac
done

if ((CREATE)) ; then
  # Create our initramfs
  [ -f "${KERNEL}" ] && rm "${KERNEL}"
  [ -f "${INITRD}" ] && rm "${INITRD}"

  # Try to find the local dracut first
  PATH=./dracut:${PATH} ../bin/generate-zbm -c ./local.yaml
fi

# Ensure kernel and initramfs exist
if [ ! -f "${KERNEL}" ] ; then
  echo "Missing kernel: ${KERNEL}"
  exit
elif [ ! -f "${INITRD}" ] ; then
  echo "Missing initramfs: ${INITRD}"
  exit
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
	-display "${DISPLAY_TYPE}" \
	-serial mon:stdio \
	-netdev user,id=n1,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=n1 \
	-append "${APPEND}"

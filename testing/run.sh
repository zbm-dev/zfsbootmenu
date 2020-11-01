#!/bin/bash
usage() {
  cat <<EOF
Usage: $0 [options]
  -a  Set kernel command line
  -d+ Set one or more non-standard disk images 
  -n  Do not recreate the initramfs
EOF
}

# Support x86_64 and ppc64(le)
case "$(uname -m)" in
  ppc64*)
    BIN="qemu-system-ppc64"
    KERNEL="vmlinux-bootmenu"
    MACHINE="pseries,accel=kvm,kvm-type=HV,cap-hpt-max-page-size=4096"
    APPEND="loglevel=7 timeout=5 root=zfsbootmenu:POOL=ztest console=hvc0 console=tty0"
  ;;
  x86_64)
    BIN="qemu-system-x86_64"
    KERNEL="vmlinuz-bootmenu"
    MACHINE="type=q35,accel=kvm"
    APPEND="loglevel=7 timeout=5 root=zfsbootmenu:POOL=ztest"
  ;;
esac

DRIVE="-drive format=raw,file=zfsbootmenu-pool.img"
INITRD="initramfs-bootmenu.img"
MEMORY="2048M"
SMP="2"
DISPLAY_TYPE="gtk"
CREATE=1

# Override any default variables
#shellcheck disable=SC1091
[ -f .config ] && source .config

while getopts "A:a:d:nh" opt; do
  case "${opt}" in
    A)
      AAPPEND+=( "$OPTARG" )
      ;;
    a)
      APPEND="${OPTARG}"
      ;;
    d)
      MDRIVE+=("-drive format=raw,file=${OPTARG}")
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

if [ "${#MDRIVE[@]}" -gt 0 ]; then
  DRIVE="${MDRIVE[*]}"
fi

if [ "${#AAPPEND[@]}" -gt 0 ]; then
  APPEND="${APPEND} ${AAPPEND[*]}"
fi

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

# shellcheck disable=SC2086
"${BIN}" \
	-kernel "${KERNEL}" \
	-initrd "${INITRD}" \
	${DRIVE} \
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

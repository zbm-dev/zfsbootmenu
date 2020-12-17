#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

usage() {
  cat <<EOF
Usage: $0 [options]
  -a  Set kernel command line
  -A+ Append additional arguments to kernel command line
  -d+ Set one or more non-standard disk images 
  -n  Do not recreate the initramfs
  -s  Enable serial console on stdio
  -v  Set type of qemu display to use
  -D  Set test directory
EOF
}

CMDOPTS="D:A:a:d:nsv:h"

# First-pass option parsing just looks for test directory
while getopts "${CMDOPTS}" opt; do
  case "${opt}" in
    D)
      TESTDIR="${OPTARG}"
      ;;
    \?|h)
      usage
      exit
      ;;
    *)
      ;;
  esac
done

if [ -n "${TESTDIR}" ]; then
  # If a test directory was specified, it must exist
  if [ ! -d "${TESTDIR}" ]; then
    echo "ERROR: test directory '${TESTDIR}' does not exist"
    exit 1
  fi
else
  # If a test directory was not specified, try a default
  TESTDIR="./test.$(uname -m)"
  [ -d "${TESTDIR}" ] || TESTDIR="."
fi

# Support x86_64 and ppc64(le)
case "$(uname -m)" in
  ppc64*)
    BIN="qemu-system-ppc64"
    KERNEL="${TESTDIR}/vmlinux-bootmenu"
    MACHINE="pseries,accel=kvm,kvm-type=HV,cap-hpt-max-page-size=4096"
    APPEND="loglevel=7 zbm.timeout=5 root=zfsbootmenu:POOL=ztest"
    SERDEV="hvc0"
  ;;
  x86_64)
    BIN="qemu-system-x86_64"
    KERNEL="${TESTDIR}/vmlinuz-bootmenu"
    MACHINE="type=q35,accel=kvm"
    APPEND="loglevel=7 zbm.timeout=5 root=zfsbootmenu:POOL=ztest"
    SERDEV="ttyS0"
  ;;
esac

DRIVE=()
INITRD="${TESTDIR}/initramfs-bootmenu.img"
MEMORY="2048M"
SMP="2"
CREATE=1
SERIAL=0
DISPLAY_TYPE=

# Override any default variables
#shellcheck disable=SC1091
[ -f .config ] && source .config

# Second-pass option parsing grabs all other options
OPTIND=1
while getopts "${CMDOPTS}" opt; do
  case "${opt}" in
    A)
      AAPPEND+=( "$OPTARG" )
      ;;
    a)
      APPEND="${OPTARG}"
      ;;
    d)
      if _dimg="$( realpath -e "${OPTARG}")"; then
        DRIVE+=("-drive" "format=raw,file=${_dimg}")
      elif _dimg="$(realpath -e "${TESTDIR}/${OPTARG}")"; then
        DRIVE+=("-drive" "format=raw,file=${_dimg}")
      else
        echo "ERROR: disk image '${OPTARG}' does not exist"
        exit 1
      fi
      ;;
    n)
      CREATE=0
      ;;
    s)
      SERIAL=1
      ;;
    v)
      DISPLAY_TYPE="${OPTARG}"
      ;;
    *)
      ;;
  esac
done

# If no drives were specified, glob all -pool.img disks
if [ "${#DRIVE[@]}" -eq 0 ]; then
  for _dimg in "${TESTDIR}"/*-pool.img; do
    DRIVE+=("-drive" "format=raw,file=${_dimg}")
  done
fi

if [ -n "${DISPLAY_TYPE}" ]; then
  # Use the indicated graphical display
  DISPLAY_ARGS=( "-display" "${DISPLAY_TYPE}" )
else
  # Suppress graphical display (implies serial mode)
  DISPLAY_ARGS=( "-nographic" )
  SERIAL=1
fi

if ((SERIAL)) ; then
  AAPPEND+=( "console=tty1" "console=${SERDEV}" )
  LINES="$( tput lines 2>/dev/null )"
  COLUMNS="$( tput cols 2>/dev/null )"
  [ -n "${LINES}" ] && AAPPEND+=( "zbm.lines=${LINES}" )
  [ -n "${COLUMNS}" ] && AAPPEND+=( "zbm.columns=${COLUMNS}" )
else
  AAPPEND+=("console=${SERDEV}" "console=tty1")
fi

if [ "${#AAPPEND[@]}" -gt 0 ]; then
  APPEND="${APPEND} ${AAPPEND[*]}"
fi

if ((CREATE)) ; then
  # Create our initramfs
  [ -f "${KERNEL}" ] && rm "${KERNEL}"
  [ -f "${INITRD}" ] && rm "${INITRD}"

  # Try to find the local dracut and generate-zbm first
  if ! ( cd "${TESTDIR}" && PATH=./dracut:${PATH} ./generate-zbm -c ./local.yaml ); then
    echo "ERROR: unable to create ZFSBootMenu images"
    exit 1
  fi
fi

# Ensure kernel and initramfs exist
if [ ! -f "${KERNEL}" ] ; then
  echo "Missing kernel: ${KERNEL}"
  exit 1
elif [ ! -f "${INITRD}" ] ; then
  echo "Missing initramfs: ${INITRD}"
  exit 1
fi

# shellcheck disable=SC2086
"${BIN}" \
	-kernel "${KERNEL}" \
	-initrd "${INITRD}" \
	"${DRIVE[@]}" \
	-m "${MEMORY}" \
	-smp "${SMP}" \
	-cpu host \
	-machine "${MACHINE}" \
	-object rng-random,id=rng0,filename=/dev/urandom \
	-device virtio-rng-pci,rng=rng0 \
	"${DISPLAY_ARGS[@]}" \
	-serial mon:stdio \
	-netdev user,id=n1,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=n1 \
	-append "${APPEND}" || exit 1

if ((SERIAL)); then
  reset
fi

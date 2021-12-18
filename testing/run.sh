#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

cleanup() {
  [ -f "${SSH_CONF_DIR}/${TESTHOST}" ] && rm "${SSH_CONF_DIR}/${TESTHOST}"
  exit
}

usage() {
  cat <<EOF
Usage: $0 [options]
  -a  Set kernel command line
  -A+ Append additional arguments to kernel command line
  -d+ Set one or more non-standard disk images
  -f  Force recreation of the initramfs
  -s  Enable serial console on stdio
  -v  Set type of qemu display to use
  -D  Set test directory
  -i  Enable dropbear remote access via crypt-ssh
  -n  Do not reset the controlling terminal after the VM exits
  -e  Boot the VM with an EFI bundle
EOF
}

CMDOPTS="D:A:a:d:fsv:hine"

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
  TESTDIR="."
  for TESTBED in void void-musl arch debian; do
    if [ -d "./test.${TESTBED}" ]; then
      TESTDIR="./test.${TESTBED}"
      break
    fi
  done
fi

# Support x86_64 and ppc64(le)
case "$(uname -m)" in
  ppc64*)
    BIN="qemu-system-ppc64"
    KERNEL="${TESTDIR}/vmlinux-bootmenu"
    MACHINE="pseries,accel=kvm,kvm-type=HV,cap-hpt-max-page-size=4096"
    APPEND="loglevel=7 zbm.show"
    SERDEV="hvc0"
  ;;
  x86_64)
    BIN="qemu-system-x86_64"
    KERNEL="${TESTDIR}/vmlinuz-bootmenu"
    MACHINE="type=q35,accel=kvm"
    APPEND="loglevel=7 zbm.show"
    SERDEV="ttyS0"
  ;;
  *)
    echo "Unknown machine type '$(uname -m)', please add it to run.sh"
    exit 1
esac

DRIVE=()
BFILES=()
INITRD="${TESTDIR}/initramfs-bootmenu.img"
OVMF="stubs/OVMF_CODE.fd"
MEMORY="2048M"
SMP="2"
CREATE=0
SERIAL=0
DISPLAY_TYPE=
SSH_INCLUDE=0
RESET=1
EFI=0

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
    f)
      CREATE=1
      ;;
    s)
      SERIAL=1
      ;;
    v)
      DISPLAY_TYPE="${OPTARG}"
      ;;
    i)
      SSH_INCLUDE=1
      ;;
    n)
      RESET=0
      ;;
    e)
      case "$(uname -m)" in
        x86_64)
          BUNDLE="${TESTDIR}/vmlinuz.EFI"
          KERNEL=
          INITRD=
          EFI=1
          ;;
        *)
          echo "EFI bundles unsupported on $(uname -m)"
          ;;
        esac
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

SSH_PORT=2222
while true; do
  PID="$( lsof -Pi :${SSH_PORT} -sTCP:LISTEN -t )"
  if [ -n "${PID}" ] ; then
    SSH_PORT=$((SSH_PORT+1))
    continue
  else
    break
  fi
done


if ((SSH_INCLUDE)); then
  export SSH_CONF_DIR="${HOME}/.ssh/zfsbootmenu.d"
  [ -d "${SSH_CONF_DIR}" ] || mkdir "${SSH_CONF_DIR}" && chmod 700 "${SSH_CONF_DIR}"

  echo "Creating host records in ${SSH_CONF_DIR}"

  # Strip directory components
  TESTHOST="${TESTDIR##*/}"
  # Make sure the host starts with "test." even if the directory does not
  TESTHOST="test.${TESTHOST#test.}"

  [ "${TESTHOST}" = "test." ] && TESTHOST=""

  export TESTHOST

  if [ -n "${TESTHOST}" ]; then
    cat << EOF > "${SSH_CONF_DIR}/${TESTHOST}"
Host ${TESTHOST}
  HostName localhost
  Port ${SSH_PORT}
  User root
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
  LogLevel error
EOF
  fi

  cat << EOF > "${TESTDIR}/dracut.conf.d/crypt-ssh.conf"
dropbear_acl="${HOME}/.ssh/authorized_keys"
dropbear_port="22"
add_dracutmodules+=" crypt-ssh "
EOF

  AAPPEND+=("ip=dhcp" "rd.neednet")

  chmod 0600 "${SSH_CONF_DIR}/${TESTHOST}"
  trap cleanup EXIT INT TERM
else
  cat << EOF > "${TESTDIR}/dracut.conf.d/crypt-ssh.conf"
omit_dracutmodules+=" crypt-ssh "
EOF
fi

# Creation is required if either kernel or initramfs is missing
if ((EFI)) ; then
  [ ! -f "${BUNDLE}" ] && CREATE=1
else
  if [ -n "${KERNEL}" ] && [ ! -f "${KERNEL}" ] || [ -n "${INITRD}" ] && [ ! -f "${INITRD}" ]; then
    CREATE=1
  fi
fi

if ((CREATE)) ; then
  yamlconf="${TESTDIR}/local.yaml"
  STUBS="$(realpath -e stubs)"

  if ((EFI)) ; then
    # toggle only EFI bundle creation
    [ -f "${BUNDLE}" ] && rm "${BUNDLE}"
    yq-go eval ".EFI.Enabled = true" -i "${yamlconf}"
    yq-go eval ".Components.Enabled = false" -i "${yamlconf}"
    yq-go eval ".EFI.Stub = \"${STUBS}/linuxx64.efi.stub\"" -i "${yamlconf}"
  else
    # toggle only component creation
    [ -f "${KERNEL}" ] && rm "${KERNEL}"
    [ -f "${INITRD}" ] && rm "${INITRD}"
    yq-go eval ".EFI.Enabled = false" -i "${yamlconf}"
    yq-go eval ".Components.Enabled = true" -i "${yamlconf}"
  fi

  # Try to find the local dracut and generate-zbm first
  if ! ( cd "${TESTDIR}" && PATH=./dracut:${PATH} ./generate-zbm -c ./local.yaml ); then
    echo "ERROR: unable to create ZFSBootMenu images"
    exit 1
  fi

  # always revert to component builds
  if ((EFI)) ; then
    yq-go eval ".EFI.Enabled = false" -i "${yamlconf}"
    yq-go eval ".Components.Enabled = true" -i "${yamlconf}"
  fi
fi

# Ensure kernel and initramfs exist
if [ -n "${KERNEL}" ] && [ ! -f "${KERNEL}" ] ; then
  echo "Missing kernel: ${KERNEL}"
  exit 1
elif [ -n "${INITRD}" ] && [ ! -f "${INITRD}" ] ; then
  echo "Missing initramfs: ${INITRD}"
  exit 1
elif [ -n "${BUNDLE}" ] && [ ! -f "${BUNDLE}" ] ; then
  echo "Missing EFI bundle: ${BUNDLE}"
  exit 1
fi

if ((EFI)) ; then
  BFILES+=( "-bios" "${OVMF}" )
  BFILES+=( "-kernel" "${BUNDLE}" )
else
  BFILES+=( "-kernel" "${KERNEL}" )
  BFILES+=( "-initrd" "${INITRD}" )
fi

if [ "${#AAPPEND[@]}" -gt 0 ]; then
  APPEND="${APPEND} ${AAPPEND[*]}"
fi

# shellcheck disable=SC2086
"${BIN}" \
	"${BFILES[@]}" \
	"${DRIVE[@]}" \
	-m "${MEMORY}" \
	-smp "${SMP}" \
	-cpu host \
	-machine "${MACHINE}" \
	-object rng-random,id=rng0,filename=/dev/urandom \
	-device virtio-rng-pci,rng=rng0 \
	"${DISPLAY_ARGS[@]}" \
	-serial mon:stdio \
	-netdev user,id=n1,hostfwd=tcp::${SSH_PORT}-:22 -device virtio-net-pci,netdev=n1 \
	-append "${APPEND}" || exit 1

if ((SERIAL)) && ((RESET)); then
  reset
fi

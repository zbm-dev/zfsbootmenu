#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

cleanup() {
  [ -f "${SSH_CONF_DIR}/${TESTHOST}" ] && rm "${SSH_CONF_DIR}/${TESTHOST}"
  [ -n  "${perf_data_PID}" ] && kill "${perf_data_PID}"
  [ -n "${FIFO}" ] && [ -e "${FIFO}.out" ] && rm "${FIFO}.out"
  [ -n "${FIFO}" ] && [ -e "${FIFO}.in" ] && rm "${FIFO}.in"
  exit
}

error() {
  echo "ERROR:" "$@"
  exit 1
}

usage() {
  cat <<-EOF
Usage: $0 [OPTIONS] [FLAGS]

  Run a ZFSBootMenu testbed

OPTIONS
  -a  <cmdline>
      Set kernel command line

  -A <argument> (May be repeated)
     Append additional argument to kernel command line

  -C <cpus>
     Set the number of CPUs in the virtual machine

  -d <image> (May be repeated)
     Attach the specified disk image to the test VM

  -D <testbed-path>
     Boot the testbed contained in the given directory

  -M <memory>
     Set the amount of memory in the virtual machine

  -o <distro>
     Attempt to boot image for a specific distribution;
     requires boot files with a ".<distro>" extension

  -S <efi-stub>
     When creating EFI bundles, use the stub at the given path

  -v <display>
     Select the qemu display type

FLAGS
  -f  Force recreation of the initramfs

  -i  Use mkinitcpio to generate the testing initramfs
  -B  Use Busybox for mkinitcpio miser mode

  -r  Use Dracut to generate the testing initramfs

  -e  Boot the VM with an EFI bundle
  -p  Boot the VM with the kernel/initramfs pair

  -E  Enable early initramfs tracing
  -F  Generate a flamegraph/flamechart using tracing data from ZBM
  -G  Enable debug output for generate-zbm

  -c  Enable dropbear remote access via crypt-ssh

  -n  Do not reset the controlling terminal after the VM exits

  -s  Enable serial console on stdio

  -h  Show this message and exit
EOF
}

CMDOPTS="a:A:C:d:D:M:o:S:v:fiBrepEFGcnsh"


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
    error "test directory '${TESTDIR}' does not exist"
  fi
else
  # If a test directory was not specified, try a default
  TESTDIR="."
  for TESTBED in ./test.*; do
    if [ -d "${TESTBED}" ]; then
      TESTDIR="${TESTBED}"
      break
    fi
  done
fi

# Support x86_64 for now
case "$(uname -m)" in
  x86_64)
    QEMU_BIN="qemu-system-x86_64"
    MACHINE="type=q35,accel=kvm"
    SERDEV="ttyS"
    ;;
  *)
    error "Unknown machine type '$(uname -m)', please add it to run.sh"
    ;;
esac

KCL="loglevel=7 zbm.show"
DRIVE=()
MEMORY="2048M"
SMP="2"
CREATE=0
SERIAL=0
DISPLAY_TYPE=
SSH_INCLUDE=0
RESET=1
EFI=
GENZBM_FLAGS=()
MISER=0
EFISTUB=
SUFFIX=

FLAME=0
EARLY_TRACING=0

# Defer a choice on initramfs generator until options are parsed
DRACUT=0
INITCPIO=0

# Override any default variables
#shellcheck disable=SC1091
[ -f .config ] && source .config

# Second-pass option parsing grabs all other options
OPTIND=1
while getopts "${CMDOPTS}" opt; do
  case "${opt}" in
    A)
      APPEND+=( "$OPTARG" )
      ;;
    a)
      KCL="${OPTARG}"
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
    c)
      SSH_INCLUDE=1
      ;;
    n)
      RESET=0
      ;;
    e)
      case "$(uname -m)" in
        x86_64) EFI=1 ;;
        *) echo "EFI bundles unsupported on $(uname -m)" ;;
      esac
      ;;
    p)
      EFI=0
      ;;
    S)
      EFISTUB="$( realpath -e "${OPTARG}" )"
      ;;
    M)
      MEMORY="${OPTARG}"
      ;;
    C)
      SMP="${OPTARG}"
      ;;
    F)
      FLAME=1
      ;;
    E)
      EARLY_TRACING=1
      FLAME=1
      ;;
    G)
      GENZBM_FLAGS+=( "-d" )
      ;;
    i)
      DRACUT=0
      INITCPIO=1
      ;;
    r)
      DRACUT=1
      INITCPIO=0
      ;;
    B)
      MISER=1
      ;;
    o)
      SUFFIX=".${OPTARG}"
      ;;
    *)
      ;;
  esac
done

if ! ((INITCPIO)) && ! ((DRACUT)); then
  # Prefer mkinitcpio if available
  if command -v mkinitcpio >/dev/null 2>&1 && [ -d "${TESTDIR}/mkinitcpio.d" ]; then
    INITCPIO=1
  else
    DRACUT=1
  fi
elif ((INITCPIO)) && ((DRACUT)); then
    echo "ERROR: dracut and mkinitcpio are mutually exclusive"
    exit 1
fi

# Verify that necessary configuration snippets are available
if ((DRACUT)); then
  if [ ! -d "${TESTDIR}/dracut.conf.d" ]; then
    echo "ERROR: cannot use dracut without dracut.conf.d"
    exit 1
  fi
elif ((INITCPIO)); then
  if [ ! -d "${TESTDIR}/mkinitcpio.d" ]; then
    echo "ERROR: cannot use mkinitcpio without mkinitcpio.d"
    exit 1
  fi

  # Directoy initcpio logs to the kernel buffer
  APPEND+=( "rd.log=kmsg" )
fi

# Remove any customizations from the last run
rm -f "${TESTDIR}/dracut.conf.d/testing.conf"
rm -f "${TESTDIR}/mkinitcpio.d/testing.conf"

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

  if ((DRACUT)); then
    cat <<-EOF >> "${TESTDIR}/dracut.conf.d/testing.conf"
	omit_dracutmodules+=" i18n "
	EOF
  fi
fi

SERDEV_COUNT=0

if ((SERIAL)) ; then
  APPEND+=( "console=tty1" "console=${SERDEV}${SERDEV_COUNT},115200n8" )
  ((SERDEV_COUNT++))
  LINES="$( tput lines 2>/dev/null )"
  COLUMNS="$( tput cols 2>/dev/null )"
  [ -n "${LINES}" ] && APPEND+=( "zbm.lines=${LINES}" )
  [ -n "${COLUMNS}" ] && APPEND+=( "zbm.columns=${COLUMNS}" )
  SOPTS+=( "-serial" "mon:stdio" )
else
  APPEND+=("console=tty1")
fi

if ((FLAME)) ; then
  FIFO="$( realpath -e "${TESTDIR}" )/guest"
  SOPTS+=( "-serial" "pipe:${FIFO}" )
  [ -e "${FIFO}.out" ] || mkfifo "${FIFO}.out"
  [ -e "${FIFO}.in" ] || mkfifo "${FIFO}.in"

  #shellcheck disable=SC2034
  coproc perf_data ( sed 's,^.*\(trapdebug*\),\1,g' < "${FIFO}.out" > "${TESTDIR}/perfdata.log" )
  trap cleanup EXIT INT TERM

  for _cdir in "dracut.conf.d" "mkinitcpio.d"; do
    [ -d "${TESTDIR}/${_cdir}" ] || continue
    cat <<-EOF >> "${TESTDIR}/${_cdir}/testing.conf"
	zfsbootmenu_trace_enable=yes
	zfsbootmenu_trace_term="/dev/${SERDEV}${SERDEV_COUNT}"
	zfsbootmenu_trace_baud="115200"
	EOF
  done

  # TODO: add support for initcpio
  if ((EARLY_TRACING)) && ((DRACUT)); then
    cat <<-EOF >> "${TESTDIR}/dracut.conf.d/testing.conf"
	dracut_trace_enable=yes
	EOF
  fi

  ((SERDEV_COUNT++))
  CREATE=1
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

  if [ ! -d "${SSH_CONF_DIR}" ]; then
    mkdir "${SSH_CONF_DIR}" && chmod 700 "${SSH_CONF_DIR}"
  fi

  if [ -d "${SSH_CONF_DIR}" ]; then
    echo "Creating host records in ${SSH_CONF_DIR}"

    # Strip directory components
    TESTHOST="${TESTDIR##*/}"
    # Make sure the host starts with "test." even if the directory does not
    TESTHOST="test.${TESTHOST#test.}"

    [ "${TESTHOST}" = "test." ] && TESTHOST=""

    export TESTHOST

    # Write an SSH config to allow easy access to the VM
    if [ -n "${TESTHOST}" ]; then
      cat <<-EOF > "${SSH_CONF_DIR}/${TESTHOST}"
	Host ${TESTHOST}
	  HostName localhost
	  Port ${SSH_PORT}
	  User root
	  UserKnownHostsFile /dev/null
	  StrictHostKeyChecking no
	  LogLevel error
	EOF
    fi

    chmod 0600 "${SSH_CONF_DIR}/${TESTHOST}"
    trap cleanup EXIT INT TERM
  fi

  # TODO: add support for initcpio
  if ((DRACUT)); then
    cat <<-EOF >> "${TESTDIR}/dracut.conf.d/testing.conf"
	dropbear_acl="${HOME}/.ssh/authorized_keys"
	dropbear_port="22"
	add_dracutmodules+=" crypt-ssh "
	EOF
    APPEND+=("ip=dhcp" "rd.neednet")
  fi
else
  if ((DRACUT)); then
    cat <<-EOF >> "${TESTDIR}/dracut.conf.d/testing.conf"
	omit_dracutmodules+=" crypt-ssh network-legacy "
	EOF
  fi
fi

# These are not needed for our testing setup, and are quite expensive
if ((DRACUT)); then
  cat <<-EOF >> "${TESTDIR}/dracut.conf.d/testing.conf"
	omit_dracutmodules+=" nvdimm fs-lib rootfs-block dm dmraid lunmask "
	EOF
fi

# Enable initcpio miser mode, using Busybox where possible
if ((INITCPIO)) && ((MISER)); then
  cat <<-EOF >> "${TESTDIR}/mkinitcpio.d/testing.conf"
  zfsbootmenu_miser=yes
	EOF
fi

# Image files the testbed may need to boot
BUNDLE="${TESTDIR}/vmlinuz.EFI${SUFFIX}"
KERNEL="${TESTDIR}/vmlinuz-bootmenu${SUFFIX}"
INITRD="${TESTDIR}/initramfs-bootmenu.img${SUFFIX}"

if [ -z "${EFI}" ]; then
  # If an EFI option was not chosen, select a workable default
  EFI=0
  [ -f "${BUNDLE}" ] && EFI=1
fi

# Creation is required if either kernel or initramfs is missing
if ((EFI)) ; then
  [ -f "${BUNDLE}" ] || CREATE=1
else

  [ -f "${KERNEL}" ] || CREATE=1
  [ -f "${INITRD}" ] || CREATE=1
fi

if ((CREATE)) && [ -n "${SUFFIX}" ]; then
  error "distribution-specific images do not exist and will not be created"
fi

if ((CREATE)) ; then
  yamlconf="${TESTDIR}/local.yaml"

  if ((EFI)) ; then
    # toggle only EFI bundle creation
    rm -f "${BUNDLE}"
    yq-go eval ".EFI.Enabled = true" -i "${yamlconf}"
    yq-go eval ".Components.Enabled = false" -i "${yamlconf}"

    [ -n "${EFISTUB}" ] || EFISTUB="$( realpath -e stubs/linuxx64.efi.stub )"
    yq-go eval ".EFI.Stub = \"${EFISTUB}\"" -i "${yamlconf}"
  else
    # toggle only component creation
    rm -f "${KERNEL}" "${INITRD}"
    yq-go eval ".EFI.Enabled = false" -i "${yamlconf}"
    yq-go eval ".Components.Enabled = true" -i "${yamlconf}"
  fi

  if ((DRACUT)) ; then
    GENZBM_FLAGS+=( "--no-initcpio" )
  elif ((INITCPIO)) ; then
    GENZBM_FLAGS+=( "--initcpio" )
  else
    GENZBM_FLAGS+=( "--initcpio" )
  fi

  # Try to find the local dracut and generate-zbm first
  if ! ( cd "${TESTDIR}" && PATH=./dracut:${PATH} ./generate-zbm -c ./local.yaml "${GENZBM_FLAGS[@]}" ); then
    error "unable to create ZFSBootMenu images"
  fi

  # always revert to component builds
  if ((EFI)) ; then
    yq-go eval ".EFI.Enabled = false" -i "${yamlconf}"
    yq-go eval ".Components.Enabled = true" -i "${yamlconf}"
  fi
fi

# Ensure ZBM image exists
if ((EFI)) ; then
  [ -f "${BUNDLE}" ] || error "Missing EFI bundle: ${BUNDLE}"

  OVMF="stubs/OVMF_CODE.fd"
  [ -f "${OVMF}" ] || error "Missing OVMF firmware: ${OVMF}"

  BFILES=( "-bios" "${OVMF}" "-kernel" "${BUNDLE}" )
else
  [ -f "${KERNEL}" ] || error "Missing kernel: ${KERNEL}"
  [ -f "${INITRD}" ] || error "Missing initramfs: ${INITRD}"

  BFILES=( "-kernel" "${KERNEL}" "-initrd" "${INITRD}" )
fi

if [ "${#APPEND[@]}" -gt 0 ]; then
  #shellcheck disable=SC2178,SC2128
  KCL="${KCL} ${APPEND[*]}"
  true
fi

# shellcheck disable=SC2086
"${QEMU_BIN}" \
  "${BFILES[@]}" \
  "${DRIVE[@]}" \
  -m "${MEMORY}" \
  -smp "${SMP}" \
  -cpu host \
  -machine "${MACHINE}" \
  -object rng-random,id=rng0,filename=/dev/urandom \
  -device virtio-rng-pci,rng=rng0 \
  "${DISPLAY_ARGS[@]}" \
  "${SOPTS[@]}" \
  -netdev user,id=n1,hostfwd=tcp::${SSH_PORT}-:22 -device virtio-net-pci,netdev=n1 \
  -append "${KCL}" || exit 1

if ((SERIAL)) && ((RESET)); then
  reset
fi

if ((FLAME)) && [ -f "${TESTDIR}/perfdata.log" ] && command -v flamegraph.pl >/dev/null 2>&1 ; then
  perl rollup.pl -m chart < "${TESTDIR}/perfdata.log" | flamegraph.pl \
    --title "${TESTDIR}: ${KCL}" \
    --height 32 \
    --width 1600 \
    --countname microseconds \
    --flamechart > "${TESTDIR}/flamechart.svg" 2>/dev/null

  perl rollup.pl -m graph < "${TESTDIR}/perfdata.log" | flamegraph.pl \
    --title "${TESTDIR}: ${KCL}" \
    --height 32 \
    --width 1600 \
    --countname microseconds > "${TESTDIR}/flamegraph.svg" 2>/dev/null

  if command -v webify >/dev/null 2>&1 ; then
    webify -p "${TESTDIR}/flamechart.svg"
    webify -p "${TESTDIR}/flamegraph.svg"
  else
    echo "Created ${TESTDIR}/flamechart.svg"
    echo "Created ${TESTDIR}/flamegraph.svg"
  fi
fi

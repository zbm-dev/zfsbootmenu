#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

YAML=0
GENZBM=0
IMAGE=0
MKINITCPIO=0
SIZE="5G"
POOL_PREFIX="ztest"

# Dracut setup requires a local installation to work
# In "all" mode, dracut is opportunistic
DRACUT="no"
CONFD=0

DISTROS=()

# Dictionary for random pool names, provided by words-en
dictfile="/usr/share/dict/words"

usage() {
  local compat_dir
  compat_dir="/usr/share/zfs/compatibility.d/"

  cat <<EOF
USAGE: $0 [options]

OPTIONS

  -h  Display this message and exit
  -y  Create local.yaml
  -g  Create a generate-zbm symlink
  -c  Create dracut.conf.d (if dracut is enabled)
  -d  Create a local dracut tree for local mode
  -m  Create mkinitcpio.conf
  -i  Create a test VM image
  -a  Perform all create options
  -D  Specify a test directory to use
  -s  Specify size of VM image
  -e  Enable native ZFS encryption
  -p  Specify a pool name
  -r  Use a randomized pool name
  -x  Use an existing pool image
  -k  Populate host SSH host and authorized keys
  -M  Build the test image on bare metal rather than a VM
  -E  Add a variable to the image-creation environment
  -o  Distribution to install (may specify more than one)
      [ void, void-musl, alpine, chimera, arch, debian, ubuntu ]

ENVIRONMENT VARIABLES

  Certain variables, when set with -E, allow customization of test images:

  RELEASE (Debian, Ubuntu)
  Specify a particular release to install in the test image
  (e.g., "bullseye", "bookworm" or "buster" for Debian; "kinetic" or "jammy" for ubuntu)

  APT_REPOS (Debian, Ubuntu)
  Specify a space-separated list of specific repositories to configure for apt
  (e.g., "main universe multiverse")

  KERNEL (Void)
  Set KERNEL to the Void kernel series to use (e.g., "linux5.10", "linux6.1")

  ZPOOL_COMPAT (All)
  Set ZPOOL_COMPAT to one of the ZFS pool compatiblity targets listed below.

$( find "${compat_dir}" -type f | sort | sed "s|${compat_dir}||" | column | sed 's/^/\t/' )
EOF
}

random_dict_value() {
  sed -n "$(shuf -i 1-"$( wc -l "${dictfile}" | cut -d ' ' -f 1)" -n 1)"p "${dictfile}" \
    | sed s/\'s// \
    | tr '[:upper:]' '[:lower:]'
}

random_name() {
  echo "$( random_dict_value )$( random_dict_value | sed -e 's/\b./\u\0/' )"
}

if [ $# -eq 0 ]; then
  usage
  exit
fi

# Environment variables to set for the image creation
ENVIRONS=(
  PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
)

while getopts "heycgdaiD:s:o:lp:rxkmE:M" opt; do
  case "${opt}" in
    e)
      ENCRYPT=1
      ;;
    y)
      YAML=1
      ;;
    c)
      CONFD=1
      ;;
    i)
      IMAGE=1
      ;;
    d)
      DRACUT="yes"
      ;;
    g)
      GENZBM=1
      ;;
    m)
      MKINITCPIO=1
      ;;
    a)
      YAML=1
      CONFD=1
      IMAGE=1
      GENZBM=1
      MKINITCPIO=1
      # Dracut is opportunistic unless forced earlier
      [ "${DRACUT}" = yes ] || DRACUT="maybe"
      ;;
    D)
      TESTDIR="${OPTARG}"
      ;;
    s)
      SIZE="${OPTARG}"
      ;;
    o)
      DISTROS+=( "${OPTARG}" )
      ;;
    p)
      POOL_PREFIX="${OPTARG}"
      ;;
    r)
      if [ -r "${dictfile}" ]; then
        RANDOM_NAME=1
      fi
      ;;
    x)
      EXISTING_POOL=1
      ;;
    k)
      INCLUDE_KEYS=1
      ;;
    E)
      ENVIRONS+=( "${OPTARG}" )
      ;;
    M)
      BARE_METAL=1
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

if [ "${#DISTROS[@]}" -lt 1 ]; then
  DISTROS=( "void" )
fi

# Assign a default dest directory if one was not provided
if [ -z "${TESTDIR}" ]; then
  TESTDIR="./test.${DISTROS[0]}"
fi

TESTDIR="$(realpath "${TESTDIR}")" || exit 1

# Make sure the test directory exists
mkdir -p "${TESTDIR}" || exit 1

# If dracut is opportunistic, determine if it should be available
if [ "${DRACUT}" = "maybe" ]; then
  if [ -d /usr/lib/dracut ] && command -v dracut >/dev/null 2>&1; then
    DRACUT="yes"
  else
    DRACUT="no"
  fi
fi

if [ "${DRACUT}" = "yes" ]; then
  DRACUTBIN="$(command -v dracut)"
  if [ ! -x "${DRACUTBIN}" ]; then
    echo "ERROR: missing dracut script"
    exit 1
  fi

  if [ ! -d /usr/lib/dracut ]; then
    echo "ERROR: missing /usr/lib/dracut"
    exit 1
  fi

  ## Populate dracut and dracut.conf.d trees if needed or demanded
  if ((CONFD)) || [ ! -d "${TESTDIR}/dracut.conf.d" ]; then
    if [ -d "${TESTDIR}/dracut.conf.d" ]; then
      echo "Re-creating dracut.conf.d"
      rm -r "${TESTDIR}/dracut.conf.d"
    else
      echo "Creating dracut.conf.d"
    fi

    if ! cp -Rp ../etc/zfsbootmenu/dracut.conf.d "${TESTDIR}"; then
      echo "ERROR: failed to create dracut.conf.d"
      exit 1
    fi

    cat >> "${TESTDIR}/dracut.conf.d/zfsbootmenu.conf" <<-EOF
	zfsbootmenu_module_root="$( realpath -e ../zfsbootmenu )"
	zfsbootmenu_hook_root="${TESTDIR}/hooks"
	EOF
  fi

  if ((CONFD)) || [ ! -d "${TESTDIR}/dracut" ]; then
    if [ -d "${TESTDIR}/dracut" ]; then
      echo "Re-creating local dracut tree"
      rm -r "${TESTDIR}/dracut"
    else
      echo "Creating local dracut tree"
    fi

    cp -a /usr/lib/dracut "${TESTDIR}"
    cp "${DRACUTBIN}" "${TESTDIR}/dracut"

    # Make sure the zfsbootmenu module is a link to the repo version
    _zbm_mod="${TESTDIR}/dracut/modules.d/90zfsbootmenu"
    if [ -L "${_zbm_mod}" ]; then
      rm "${_zbm_mod}"
    elif [ -d "${_zbm_mod}" ]; then
      rm -r "${_zbm_mod}"
    fi

    ln -Tsf "$(realpath -e ../dracut)" "${_zbm_mod}"
  fi
fi

if ((MKINITCPIO)) ; then
  cat <<-EOF > "${TESTDIR}/mkinitcpio.conf"
	for snippet in $( realpath -e "${TESTDIR}" )/mkinitcpio.d/*.conf ; do
	  source \${snippet}
	done
	EOF

  MKINITCPIOD="${TESTDIR}/mkinitcpio.d"
  mkdir -p "${MKINITCPIOD}"

  cat <<-EOF > "${MKINITCPIOD}/base.conf"
	MODULES=(ahci.ko)
	BINARIES=()
	FILES=()
	HOOKS=(base udev autodetect modconf block filesystems keyboard)
	COMPRESSION="cat"
	EOF

  cat <<-EOF > "${MKINITCPIOD}/modroot.conf"
	zfsbootmenu_module_root="$( realpath -e ../zfsbootmenu )"
	EOF

  cat <<-EOF > "${MKINITCPIOD}/hooks.conf"
	zfsbootmenu_hook_root="${TESTDIR}/hooks"
	EOF
fi

if ((GENZBM)) ; then
  rm -f "${TESTDIR}/generate-zbm"
  ln -s "$(realpath -e ../bin/generate-zbm)" "${TESTDIR}/generate-zbm"
fi

# Setup a local config file
if ((YAML)) ; then
  echo "Configuring local.yaml"
  yamlconf="${TESTDIR}/local.yaml"
  STUBS="$(realpath -e stubs)"
  cp ../etc/zfsbootmenu/config.yaml "${yamlconf}"
  yq-go eval ".Components.ImageDir = \"${TESTDIR}\"" -i "${yamlconf}"
  yq-go eval ".Components.Versions = false" -i "${yamlconf}"
  yq-go eval ".EFI.ImageDir = \"${TESTDIR}\"" -i "${yamlconf}"
  yq-go eval ".EFI.Versions = false" -i "${yamlconf}"
  yq-go eval ".EFI.Stub = \"${STUBS}/linuxx64.efi.stub\"" -i "${yamlconf}"
  yq-go eval ".Global.ManageImages = true" -i "${yamlconf}"
  yq-go eval ".Global.DracutConfDir = \"${TESTDIR}/dracut.conf.d\"" -i "${yamlconf}"
  yq-go eval ".Global.PreHooksDir = \"${TESTDIR}/generate-zbm.pre.d\"" -i "${yamlconf}"
  yq-go eval ".Global.PostHooksDir = \"${TESTDIR}/generate-zbm.post.d\"" -i "${yamlconf}"
  yq-go eval ".Global.InitCPIOConfig = \"${TESTDIR}/mkinitcpio.conf\"" -i "${yamlconf}"
  yq-go eval ".Global.InitCPIOHookDirs = [ \"$( realpath -e ../initcpio )\",\"/usr/lib/initcpio\" ]" -i "${yamlconf}"
  yq-go eval ".Global.DracutFlags = [ \"--local\" ]" -i "${yamlconf}"
  yq-go eval "del(.Global.BootMountPoint)" -i "${yamlconf}"
  yq-go eval -P -C "${yamlconf}"
fi

# seed our initial pool name attempt
if ((RANDOM_NAME)); then
  POOL_NAME="$( random_name )"
else
  POOL_NAME="${POOL_PREFIX}"
  idx=0
fi

while [ -z "${EXISTING_POOL}" ]; do
  # Check that a file doesn't exist with this name, or that
  # a currently-imported pool doesn't have this name
  if [ ! -r "${TESTDIR}/${POOL_NAME}-pool.img" ] \
    && ! zpool list -o name -H "${POOL_NAME}" >/dev/null 2>&1
  then
    break
  fi

  # Generate a new random name / bump the index
  if ((RANDOM_NAME)); then
    POOL_NAME="$( random_name )"
  else
    idx=$(( idx + 1 ))
    POOL_NAME="$( printf "${POOL_PREFIX}-%02d" "${idx}" )"
  fi
done

echo "Generated pool name: ${POOL_NAME}"

if ((INCLUDE_KEYS)); then
  # ssh-keygen expects to dump into ${PREFIX}/etc/ssh
  mkdir -p ./keys/etc/ssh
  # Generate any missing keys
  ssh-keygen -A -f ./keys

  # Copy authorized keys for convenience
  if [ -r "${HOME}/.ssh/authorized_keys" ] && [ ! -r ./keys/authorized_keys ]; then
    cp "${HOME}/.ssh/authorized_keys" ./keys/
  fi
fi

# Create image(s) for each specified distro
if ((IMAGE)); then
  for DISTRO in "${DISTROS[@]}"; do
    builder_args=( )
    for environ in "${ENVIRONS[@]}"; do
      builder_args+=( "-E" "${environ}" )
    done

    if ((EXISTING_POOL)); then
      builder_args+=( "-x" )
    else
      if ! qemu-img create "${TESTDIR}/${POOL_NAME}-pool.img" "${SIZE}"; then
        echo "ERROR: failed to create pool image"
        exit 1
      fi

      AUTO_POOL_COMPAT=1
      for environ in "${ENVIRONS[@]}"; do
        [[ "${environ}" =~ "^ZPOOL_COMPAT=" ]] || continue
        AUTO_POOL_COMPAT=0
        break
      done

      if ((AUTO_POOL_COMPAT)); then
        case "${DISTRO}" in
          debian|ubuntu) builder_args+=( -c "openzfs-2.0-linux" ) ;;
        esac
      fi
    fi

    if ((ENCRYPT)); then
      builder_args+=( -e "${TESTDIR}/${POOL_NAME}.key" )
    fi

    builder_args+=( "${DISTRO}" "${POOL_NAME}" "${TESTDIR}" )

    if ((BARE_METAL)); then
      if command -v doas >/dev/null 2>&1; then
        SUDO=doas
      elif command -v sudo >/dev/null 2>&1; then
        SUDO=sudo
      else
        echo "ERROR: unable to elevate user privileges, install sudo or doas"
        exit 1
      fi

      "${SUDO}" unshare --fork --pid --mount \
        ./helpers/builder-host.sh "${builder_args[@]}"
    else
      ./helpers/builder-qemu.sh "${builder_args[@]}"
    fi

    # All subsequent distros use the same pool
    EXISTING_POOL=1
  done
fi

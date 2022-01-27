#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

YAML=0
GENZBM=0
IMAGE=0
CONFD=0
DRACUT=0
MKINITCPIO=0
SIZE="5G"
POOL_PREFIX="ztest"

DISTROS=()

# Dictionary for random pool names, provided by words-en
dictfile="/usr/share/dict/words"

usage() {
  cat <<EOF
Usage: $0 [options]
  -y  Create local.yaml
  -g  Create a generate-zbm symlink
  -c  Create dracut.conf.d
  -d  Create a local dracut tree for local mode
  -m  Create mkinitcpio.conf
  -i  Create a test VM image
  -a  Perform all setup options
  -D  Specify a test directory to use
  -s  Specify size of VM image
  -e  Enable native ZFS encryption
  -l  Disable features for legacy (zfs<2.0.0) support
  -p  Specify a pool name
  -r  Use a randomized pool name
  -x  Use an existing pool image
  -k  Populate host SSH host and authorized keys
  -o  Distribution to install (may specify more than one)
      [ void, void-musl, alpine, arch, debian, ubuntu ]
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

while getopts "heycgdaiD:s:o:lp:rxkm" opt; do
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
      DRACUT=1
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
      DRACUT=1
      GENZBM=1
      MKINITCPIO=1
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
    l)
      LEGACY_POOL=1
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
    *)
      usage
      exit
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

if ((CONFD)) && [ ! -d "${TESTDIR}/dracut.conf.d" ]; then
  echo "Creating dracut.conf.d"
  cp -Rp ../etc/zfsbootmenu/dracut.conf.d "${TESTDIR}"
  echo "zfsbootmenu_module_root=\"$( realpath -e ../zfsbootmenu )\"" >> "${TESTDIR}/dracut.conf.d/zfsbootmenu.conf"
fi

if ((DRACUT)) ; then
  if [ ! -d /usr/lib/dracut ]; then
    echo "ERROR: missing /usr/lib/dracut"
    exit 1
  fi

  DRACUTBIN="$(command -v dracut)"
  if [ ! -x "${DRACUTBIN}" ]; then
    echo "ERROR: missing dracut script"
    exit 1
  fi

  if [ ! -d "${TESTDIR}/dracut" ]; then
    echo "Creating local dracut tree"
    cp -a /usr/lib/dracut "${TESTDIR}"
    cp "${DRACUTBIN}" "${TESTDIR}/dracut"
  fi

  # Make sure the zfsbootmenu module is a link to the repo version
  _dracut_mods="${TESTDIR}/dracut/modules.d"
  test -d "${_dracut_mods}" && rm -rf "${_dracut_mods}/90zfsbootmenu"
  ln -s "$(realpath -e ../dracut)" "${_dracut_mods}/90zfsbootmenu"
fi

if ((MKINITCPIO)) ; then
  cat << EOF > "${TESTDIR}/mkinitcpio.conf"
for snippet in $( realpath -e "${TESTDIR}" )/mkinitcpio.d/*.conf ; do
  source \${snippet}
done
EOF

  MKINITCPIOD="${TESTDIR}/mkinitcpio.d"
  mkdir -p "${MKINITCPIOD}"

  cat << EOF > "${MKINITCPIOD}/base.conf"
MODULES=()
BINARIES=()
FILEs=()
HOOKS=(base udev autodetect modconf block filesystems keyboard)
COMPRESSION="cat"
EOF

  cat << EOF > "${MKINITCPIOD}/modroot.conf"
zfsbootmenu_module_root="$( realpath -e ../zfsbootmenu )"
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
    IMAGE_SCRIPT="./helpers/image-${DISTRO}.sh"
    if [ ! -x "${IMAGE_SCRIPT}" ]; then
      IMAGE_SCRIPT="./helpers/image.sh"
    fi

    if command -v doas >/dev/null 2>&1; then
      SUDO=doas
    elif command -v sudo >/dev/null 2>&1; then
      SUDO=sudo
    else
      echo "ERROR: unable to elevate user privileges, install sudo or doas"
      exit 1
    fi

    "${SUDO}" unshare --fork --pid --mount env \
      ENCRYPT="${ENCRYPT}" \
      LEGACY_POOL="${LEGACY_POOL}" \
      EXISTING_POOL="${EXISTING_POOL}" \
      PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" \
      "${IMAGE_SCRIPT}" "${TESTDIR}" "${SIZE}" "${DISTRO}" "${POOL_NAME}"

    # All subsequent distros use the same pool
    EXISTING_POOL=1
  done
fi

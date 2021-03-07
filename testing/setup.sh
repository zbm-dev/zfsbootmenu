#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

YAML=0
GENZBM=0
IMAGE=0
CONFD=0
DRACUT=0
SIZE="5G"
DISTRO="void"
POOL_PREFIX="ztest"

# Dictionary for random pool names, provided by words-en
dictfile="/usr/share/dict/words"

usage() {
  cat <<EOF
Usage: $0 [options]
  -y  Create local.yaml
  -g  Create a generate-zbm symlink
  -c  Create dracut.conf.d
  -d  Create a local dracut tree for local mode
  -i  Create a test VM image
  -a  Perform all setup options
  -D  Specify a test directory to use
  -s  Specify size of VM image
  -e  Enable native ZFS encryption
  -l  Disable features for legacy (zfs<2.0.0) support
  -p  Specify a pool name
  -r  Use a randomized pool name
  -o  Specify another distribution
      [ void, void-musl, arch, debian, ubuntu ]
EOF
}

random_dict_value() {
  sed -n "$(shuf -i 1-"$( wc -l "${1}" | cut -d ' ' -f 1)" -n 1)"p "${1}" \
    | sed s/\'s// \
    | tr '[:upper:]' '[:lower:]'
}

random_name() {
  echo "$( random_dict_value "${dictfile}" )$( random_dict_value "${dictfile}" | sed -e 's/\b./\u\0/' )"
}

if [ $# -eq 0 ]; then
  usage
  exit
fi

while getopts "heycgdaiD:s:o:lp:r" opt; do
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
    a)
      YAML=1
      CONFD=1
      IMAGE=1
      DRACUT=1
      GENZBM=1
      ;;
    D)
      TESTDIR="${OPTARG}"
      ;;
    s)
      SIZE="${OPTARG}"
      ;;
    o)
      DISTRO="${OPTARG}"
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
    *)
      usage
      exit
  esac
done

# Assign a default dest directory if one was not provided
if [ -z "${TESTDIR}" ]; then
  TESTDIR="./test.${DISTRO}"
fi

TESTDIR="$(realpath "${TESTDIR}")" || exit 1

# Make sure the test directory exists
mkdir -p "${TESTDIR}" || exit 1

if ((CONFD)) && [ ! -d "${TESTDIR}/dracut.conf.d" ]; then
  echo "Creating dracut.conf.d"
  cp -Rp ../etc/zfsbootmenu/dracut.conf.d "${TESTDIR}"
  echo 'zfsbootmenu_tmux=true' > "${TESTDIR}/dracut.conf.d/tmux.conf"
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
  ln -s "$(realpath -e ../90zfsbootmenu)" "${_dracut_mods}"
fi

if ((GENZBM)) ; then
  rm -f "${TESTDIR}/generate-zbm"
  ln -s "$(realpath -e ../bin/generate-zbm)" "${TESTDIR}/generate-zbm"
fi

# Setup a local config file
if ((YAML)) ; then
  echo "Configuring local.yaml"
  yamlconf="${TESTDIR}/local.yaml"
  cp ../etc/zfsbootmenu/config.yaml "${yamlconf}"
  yq-go eval ".Components.ImageDir = \"${TESTDIR}\"" -i "${yamlconf}"
  yq-go eval ".Components.Versions = false" -i "${yamlconf}"
  yq-go eval ".Global.ManageImages = true" -i "${yamlconf}"
  yq-go eval ".Global.DracutConfDir = \"${TESTDIR}/dracut.conf.d\"" -i "${yamlconf}"
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

while true; do
  if [ ! -r "${TESTDIR}/${POOL_NAME}-pool.img" ]; then
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

# Create an image
if ((IMAGE)); then
  IMAGE_SCRIPT="./helpers/image-${DISTRO}.sh"
  if [ ! -x "${IMAGE_SCRIPT}" ]; then
    IMAGE_SCRIPT="./helpers/image.sh"
  fi

  sudo env \
    ENCRYPT="${ENCRYPT}" \
    LEGACY_POOL="${LEGACY_POOL}" \
    PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" \
    "${IMAGE_SCRIPT}" "${TESTDIR}" "${SIZE}" "${DISTRO}" "${POOL_NAME}"
fi

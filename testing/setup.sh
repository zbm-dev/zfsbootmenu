#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

YAML=0
GENZBM=0
IMAGE=0
CONFD=0
DRACUT=0
SIZE="2G"
DISTRO="void"

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
  -o  Specify another distribution
      [ void, void-musl, arch, debian, ubuntu ]
EOF
}

if [ $# -eq 0 ]; then
  usage
  exit
fi

while getopts "heycgdaiD:s:o:l" opt; do
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

# Create an image
if ((IMAGE)); then
  IMAGE_SCRIPT="./helpers/image-${DISTRO}.sh"
  if [ ! -x "${IMAGE_SCRIPT}" ]; then
    IMAGE_SCRIPT="./helpers/image.sh"
  fi

  sudo env \
    ENCRYPT="${ENCRYPT}" \
    LEGACY_POOL="${LEGACY_POOL}" \
    "${IMAGE_SCRIPT}" "${TESTDIR}" "${SIZE}" "${DISTRO}"
fi

#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

YAML=0
GENZBM=0
IMAGE=0
CONFD=0
DRACUT=0

usage() {
  cat <<EOF
Usage: $0 [options]
  -y  Create local.yaml
  -g  Create a generate-zbm symlink
  -c  Create dracut.conf.d
  -d  Create a local dracut tree for local mode
  -i  Create a test VM image
  -a  Perform all setup options
  -m  When making an image, use musl instead of glibc
  -D  Specify a test directory to use
EOF
}

if [ $# -eq 0 ]; then
  usage
  exit
fi

while getopts "ycgdaimD:" opt; do
  case "${opt}" in
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
    m)
      MUSL=1
      ;;
    D)
      TESTDIR="${OPTARG}"
      ;;
    \?)
      usage
      exit
  esac
done

# Assign a default dest directory if one was not provided
if [ -z "${TESTDIR}" ]; then
  TESTDIR="./test.$(uname -m)"
  if ((MUSL)); then
    TESTDIR="${TESTDIR}-musl"
  fi
fi

TESTDIR="$(realpath "${TESTDIR}")" || exit 1

# Make sure the test directory exists
mkdir -p "${TESTDIR}" || exit 1

if ((CONFD)) && [ ! -d "${TESTDIR}/dracut.conf.d" ]; then
  echo "Creating dracut.conf.d"
  cp -Rp ../etc/zfsbootmenu/dracut.conf.d "${TESTDIR}"
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
  cp ../etc/zfsbootmenu/config.yaml "${TESTDIR}/local.yaml"
  yq-go w -i "${TESTDIR}/local.yaml" Components.ImageDir "${TESTDIR}"
  yq-go w -i "${TESTDIR}/local.yaml" Components.Versions false
  yq-go w -i "${TESTDIR}/local.yaml" Global.ManageImages true
  yq-go w -i "${TESTDIR}/local.yaml" Global.DracutConfDir "${TESTDIR}/dracut.conf.d"
  yq-go w -i "${TESTDIR}/local.yaml" Global.DracutFlags[+] -- "--local"
  yq-go d -i "${TESTDIR}/local.yaml" Global.BootMountPoint
  yq-go r -P -C "${TESTDIR}/local.yaml"
fi

# Create an image
if ((IMAGE)) ; then
  sudo env MUSL="${MUSL}" ./image.sh "${TESTDIR}"
fi

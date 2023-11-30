#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

if [ -z "${CHROOT_MNT}" ] || [ ! -d "${CHROOT_MNT}" ]; then
  echo "ERROR: chroot mountpoint must be specified and must exist"
  exit 1
fi

if [[ "$0" =~ "ubuntu" ]]; then
  SUITE="${RELEASE:-jammy}"
  MIRROR="http://us.archive.ubuntu.com/ubuntu/"
  CONFIGURATOR="configure-ubuntu.sh"
else
  SUITE="${RELEASE:-bookworm}"
  MIRROR="http://ftp.us.debian.org/debian/"
  CONFIGURATOR="configure-debian.sh"
fi

DBARGS=()
if [ -d "${CHROOT_MNT}/hostcache" ]; then
  DBARGS+=( "--cache-dir=$( realpath -e "${CHROOT_MNT}/hostcache" )" )
fi

./helpers/debootstrap.sh "${DBARGS[@]}" "${SUITE}" "${CHROOT_MNT}" "${MIRROR}"

mkdir -p "${CHROOT_MNT}/etc"
cp /etc/hostid "${CHROOT_MNT}/etc/hostid"
cp /etc/resolv.conf "${CHROOT_MNT}/etc/resolv.conf"

if [ -d "${CHROOT_MNT}/hostcache" ]; then
  _aptdir="${CHROOT_MNT}/etc/apt/apt.conf.d"
  mkdir -p "${_aptdir}"
  echo "Dir::Cache::Archives /hostcache;" > "${_aptdir}/00hostcache"
fi

# Add post-installation setup scripts
mkdir -p "${CHROOT_MNT}/root"
for script in "${CONFIGURATOR}" "network-systemd.sh" "zbm-populate.sh"; do
  script="./helpers/${script}"
  if [ -x "${script}" ]; then
    echo "Copying post-installation script ${script} into chroot"
    cp "${script}" "${CHROOT_MNT}/root/"
  fi
done

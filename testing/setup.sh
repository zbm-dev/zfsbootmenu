#!/bin/bash
YAML=0
IMAGE=0
CONFD=0
DRACUT=0

usage() {
  cat <<EOF
Usage: $0 [options]
  -y  Create local.yaml
  -c  Create dracut.conf.d
  -d  Create a local dracut tree for local mode
  -i  Create a test VM image
  -a  Perform all setup options
EOF
}

if [ $# -eq 0 ]; then
  usage
  exit
fi

while getopts "ycdai" opt; do
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
    a)
      YAML=1
      CONFD=1
      IMAGE=1
      DRACUT=1
      ;;
    \?)
      usage
      exit
  esac
done

if ((CONFD)) ; then
  echo "Creating dracut.conf.d"
  test -d "dracut.conf.d" || cp -Rp ../etc/zfsbootmenu/dracut.conf.d .
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

  if [ ! -d dracut ]; then
    echo "Creating local dracut tree"
    cp -a /usr/lib/dracut .
    cp "${DRACUTBIN}" ./dracut
  fi

  # Make sure the zfsbootmenu module is a link to the repo version
  test -d dracut/modules.d/90zfsbootmenu && rm -rf dracut/modules.d/90zfsbootmenu
  test -L dracut/modules.d/90zfsbootmenu || ln -s ../../../90zfsbootmenu dracut/modules.d
fi

# Setup a local config file
if ((YAML)) ; then
  echo "Configuring local.yaml"
  cp ../etc/zfsbootmenu/config.yaml local.yaml
  yq-go w -i local.yaml Components.ImageDir "$( pwd )"
  yq-go w -i local.yaml Components.Versions false
  yq-go w -i local.yaml Global.ManageImages true
  yq-go w -i local.yaml Global.DracutConfDir "$( pwd )/dracut.conf.d"
  yq-go w -i local.yaml Global.DracutFlags[+] -- "--local"
  yq-go d -i local.yaml Global.BootMountPoint
  yq-go r -P -C local.yaml
fi

# Create an image
if ((IMAGE)) ; then
  SHELL=/bin/bash sudo -s <<"EOF"

  MNT="$( mktemp -d )"
  LOOP="$( losetup -f )"

  qemu-img create zfsbootmenu-pool.img 1G

  losetup "${LOOP}" zfsbootmenu-pool.img
  kpartx -u "${LOOP}"

  echo 'label: gpt' | sfdisk "${LOOP}"
  zpool create -f \
   -O compression=lz4 \
   -O acltype=posixacl \
   -O xattr=sa \
   -O relatime=on \
   -o autotrim=on \
   -o cachefile=none \
   -m none ztest "${LOOP}"

  zfs snapshot -r ztest@barepool

  zfs create -o mountpoint=none ztest/ROOT
  zfs create -o mountpoint=/ -o canmount=noauto ztest/ROOT/void

  zfs snapshot -r ztest@barebe

  zfs set org.zfsbootmenu:commandline="spl_hostid=$( hostid ) ro quiet" ztest/ROOT
  zpool set bootfs=ztest/ROOT/void ztest

  zpool export ztest
  zpool import -R "${MNT}" ztest
  zfs mount ztest/ROOT/void

  case "$(uname -m)" in
    ppc64le)
      URL="https://mirrors.servercentral.com/void-ppc/current"
      ;;
    x86_64)
      URL="https://mirrors.servercentral.com/voidlinux/current"
      ;;
  esac

  # https://github.com/project-trident/trident-installer/blob/master/src-sh/void-install-zfs.sh#L541
  mkdir -p "${MNT}/var/db/xbps/keys"
  cp /var/db/xbps/keys/*.plist "${MNT}/var/db/xbps/keys/."

  mkdir -p "${MNT}/etc/xbps.d"
  cp /etc/xbps.d/*.conf "${MNT}/etc/xbps.d/."

  # /etc/runit/core-services/03-console-setup.sh depends on loadkeys from kbd
  # /etc/runit/core-services/05-misc.sh depends on ip from iproute2
  xbps-install -y -S -M -r "${MNT}" --repository="${URL}" \
    base-minimal dracut ncurses-base kbd iproute2

  cp /etc/hostid "${MNT}/etc/"
  cp /etc/resolv.conf "${MNT}/etc/"
  cp /etc/rc.conf "${MNT}/etc/"

  mount -t proc proc "${MNT}/proc"
  mount -t sysfs sys "${MNT}/sys"
  mount -B /dev "${MNT}/dev"
  mount -t devpts pts "${MNT}/dev/pts"

  zfs snapshot -r ztest@pre-chroot

  cp chroot.sh "${MNT}/root"
  chroot "${MNT}" /root/chroot.sh

  umount -R "${MNT}" && rmdir "${MNT}"

  zpool export ztest
  losetup -d "${LOOP}"

  chown "$( stat -c %U . ):$( stat -c %G . )" zfsbootmenu-pool.img
EOF
fi

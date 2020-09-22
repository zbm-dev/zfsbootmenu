#!/bin/bash
YAML=0
MODULES=0
IMAGE=0
CONFD=0

usage() {
  cat <<EOF
Usage: $0 [options]
  -y  Create local.yaml
  -m  Create modules.d
  -c  Create dracut.conf.d
  -i  Create a test VM image
  -a  Perform all setup options
EOF
}

if [ $# -eq 0 ]; then
  usage
  exit
fi

while getopts "ymcai" opt; do
  case "${opt}" in
    y)
      YAML=1
      ;;
    m)
      MODULES=1
      ;;
    c)
      CONFD=1
      ;;
    i)
      IMAGE=1
      ;;
    a)
      YAML=1
      MODULES=1
      CONFD=1
      IMAGE=1
      ;;
    \?)
      usage
      exit
  esac
done

if ((MODULES)) ; then
# Setup our dracut directory
  echo "Creating local modules.d/"
  test -d modules.d || mkdir modules.d
  for mod in $( find /usr/lib/dracut/modules.d/ -type d | grep -v zfsbootmenu ); do
    TARGET="modules.d/$( basename "${mod}" )"
    test -L "${TARGET}" || ln -s "${mod}" "${TARGET}"
  done

  test -L "modules.d/90zfsbootmenu" || ln -s "../../90zfsbootmenu" "modules.d/90zfsbootmenu"
fi

if ((CONFD)) ; then
  echo "Creating dracut.conf.d"
  test -d "dracut.conf.d" || cp -Rp ../etc/zfsbootmenu/dracut.conf.d .
fi

# Setup a local config file
if ((YAML)) ; then
  echo "Configuring local.yaml"
  cp ../etc/zfsbootmenu/config.yaml local.yaml
  yq-go w -i local.yaml Components.ImageDir "$( pwd )"
  yq-go w -i local.yaml Components.Versions false
  yq-go w -i local.yaml Global.ManageImages true
  yq-go w -i local.yaml Global.DracutFlags[+] -- "--local"
  yq-go w -i local.yaml Global.DracutConfDir "$( pwd )/dracut.conf.d"
  yq-go d -i local.yaml Global.BootMountPoint
  yq-go r -P -C local.yaml
fi

# Create an image
if ((IMAGE)) ; then
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
fi

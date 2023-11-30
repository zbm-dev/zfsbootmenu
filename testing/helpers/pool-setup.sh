#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

usage() {
  cat <<-EOF
	USAGE: $0 [OPTIONS] <distro> <pool> [testdir]
	
	  Install a distribution into the given ZFS pool. If testdir is
	  provided and ZFSBootMenu images are built during installation,
	  the images will be copied to testdir afterwards.
	
	OPTIONS
	-h
	   Display this message and exit
	
	-c <cachedir>
	   If possible, use the given installation cache directory
	   (This can also be set as CACHEDIR in the environment)
	
	-e <keyfile>
	   If the pool is encrypted, use the given keyfile to unlock it
	   (This can also be set as ENCRYPT_KEYFILE in the environment)
	EOF
}

cleanup() {
  if [ -n "${CHROOT_MNT}" ]; then
    echo "Cleaning up chroot mount '${CHROOT_MNT}'"
    mountpoint -q "${CHROOT_MNT}" && umount -R "${CHROOT_MNT}"
    [ -d "${CHROOT_MNT}" ] && rmdir "${CHROOT_MNT}"
    unset CHROOT_MNT
  fi

  if [ -n "${ZBM_POOL}" ]; then
    echo "Exporting pool '${ZBM_POOL}'"
    zpool export "${ZBM_POOL}"
    unset ZBM_POOL
  fi

  exit
}

error() {
  echo "ERROR: $*" >&2
}

while getopts "hc:e:" opt; do
  case "${opt}" in
    c)
      CACHEDIR="${OPTARG}"
      ;;
    e)
      ENCRYPT_KEYFILE="${OPTARG}"
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

shift "$((OPTIND - 1))"

DISTRO="${1?ERROR: a distribution name is required}"
zpool_name="${2?ERROR: a pool name is required}"

TESTDIR="${3}"

INSTALL_SCRIPT="./helpers/install-${DISTRO}.sh"
if [ ! -x "${INSTALL_SCRIPT}" ]; then
  error "install script '${INSTALL_SCRIPT}' missing or not executable"
  exit 1
fi

CHROOT_SCRIPT="./helpers/chroot-${DISTRO}.sh"
if [ ! -x "${CHROOT_SCRIPT}" ]; then
  error "chroot script '${CHROOT_SCRIPT}' missing or not executable"
  exit 1
fi

export ZBM_POOL=""

CHROOT_MNT="$( mktemp -d )" || exit 1
export CHROOT_MNT

# Perform all necessary cleanup for this script
trap cleanup EXIT INT TERM

# Import the pool at the temporary chroot
if ! zpool import -o cachefile=none -R "${CHROOT_MNT}" "${zpool_name}"; then
  error "unable to import ZFS pool ${zpool_name}"
  exit 1
else
  export ZBM_POOL="${zpool_name}"
fi

# The distribution must not exist at this point
ZBM_ROOT="${ZBM_POOL}/ROOT/${DISTRO}"
if zfs list -o name -H "${ZBM_ROOT}" >/dev/null 2>&1; then
  error "ZFS filesystem ${ZBM_ROOT} already exists"
  exit 1
fi

# Unlock the pool, if required
case "$( zfs get -H -o value encryptionroot "${ZBM_POOL}" 2>/dev/null )" in
  "-"|"")
    ;;
  *)
    if [ -r "${ENCRYPT_KEYFILE}" ]; then
      zfs load-key -L "file://${ENCRYPT_KEYFILE}" "${ZBM_POOL}"
    else
      zfs load-key -L prompt "${ZBM_POOL}"
      export ENCRYPT_KEYFILE=""
    fi
esac

# Prepare the empty boot environment
zfs create -o mountpoint=/ -o canmount=noauto "${ZBM_ROOT}"
zfs snapshot -r "${ZBM_ROOT}@barebe"

zfs set org.zfsbootmenu:commandline="rw loglevel=4 console=tty1 console=ttyS0" "${ZBM_ROOT}"

zpool set bootfs="${ZBM_ROOT}" "${ZBM_POOL}"

if ! zfs mount "${ZBM_ROOT}"; then
  error "unable to mount ${ZBM_ROOT}"
  exit 1
fi

if [ -r "${ENCRYPT_KEYFILE}" ]; then
  # Make sure the ZFS key exists in the BE
  mkdir -p "${CHROOT_MNT}/etc/zfs"
  cp "${ENCRYPT_KEYFILE}" "${CHROOT_MNT}/etc/zfs/"

  # Set a ZBM key source if one is not already provided
  if [ "$( zfs get -o value -H org.zfsbootmenu:keysource "${ZBM_POOL}" )" = "-" ]; then
    zfs set "org.zfsbootmenu:keysource=${ZBM_ROOT}" "${ZBM_POOL}"
  fi
fi

# Bind-mount any cache directory in the target
CACHEDIR="$( realpath "${CACHEDIR:-./cache}" )"
if [ -d "${CACHEDIR}" ]; then
  HOSTCACHE="${CHROOT_MNT}/hostcache"
  mkdir -p "${CACHEDIR}/${DISTRO}" "${HOSTCACHE}"

  if mount -B "${CACHEDIR}/${DISTRO}" "${HOSTCACHE}"; then
    mount --make-slave "${HOSTCACHE}"
    export CACHEDIR
  else
    echo "WARNING: failed to bind-mount cache directory; ignoring"
    unset CACHEDIR
  fi
else
  unset CACHEDIR
fi

# Run the initial install
if ! "${INSTALL_SCRIPT}"; then
  echo "ERROR: install script '${INSTALL_SCRIPT}' failed"
  exit 1
fi

zfs snapshot -r "${ZBM_ROOT}@pre-chroot"

# Make sure the chroot script exists
mkdir -p "${CHROOT_MNT}/root"
cp "${CHROOT_SCRIPT}" "${CHROOT_MNT}/root/"

# Make sure special filesystems are mounted
mkdir -p "${CHROOT_MNT}"/{proc,sys,dev/pts}
mount -t proc proc "${CHROOT_MNT}/proc"
mount -t sysfs sys "${CHROOT_MNT}/sys"
mount -B /dev "${CHROOT_MNT}/dev" && mount --make-slave "${CHROOT_MNT}/dev"
mount -t devpts pts "${CHROOT_MNT}/dev/pts"

# Make sure the zpool information is cached
mkdir -p "${CHROOT_MNT}/etc/zfs"
zpool set cachefile="${CHROOT_MNT}/etc/zfs/zpool.cache" "${ZBM_POOL}"

# Set hostname for environment
echo "${DISTRO}" > "${CHROOT_MNT}/etc/hostname"

# Pre-populate SSH keys, if available
if [ -d "./keys/etc/ssh" ]; then
  cp -R "./keys/etc/ssh" "${CHROOT_MNT}/etc/"
fi

# Pre-populate authorized keys, if available
if [ -r "./keys/authorized_keys" ]; then
  mkdir -p "${CHROOT_MNT}/root/.ssh"
  chmod 700 "${CHROOT_MNT}/root/.ssh"
  cp "./keys/authorized_keys" "${CHROOT_MNT}/root/.ssh/"
fi

# Launch the chroot script
if ! chroot "${CHROOT_MNT}" "/root/${CHROOT_SCRIPT##*/}"; then
  echo "ERROR: chroot script '${CHROOT_SCRIPT}' failed"
  exit 1
fi

# Pre-populate the test environment with ZBM from the testbed
if [ -d "${CHROOT_MNT}/zfsbootmenu" ]; then
  if chroot "${CHROOT_MNT}" /usr/bin/generate-zbm --prefix vmlinuz; then
    for f in vmlinuz-bootmenu initramfs-bootmenu.img vmlinuz.EFI; do
      file="${CHROOT_MNT}/zfsbootmenu/build/${f}"
      [ -f "${file}" ] || continue

      if [ -d "${TESTDIR}" ]; then
        cp "${file}" "${TESTDIR}/${f}.${DISTRO}"
        chmod 644 "${TESTDIR}/${f}.${DISTRO}"

        if [ ! -e "${TESTDIR}/${f}" ] || [ -L "${TESTDIR}/${f}" ]; then
          ln -Tsf "${f}.${DISTRO}" "${TESTDIR}/${f}"
        fi
      fi
    done
  fi
fi

zfs snapshot -r "${ZBM_ROOT}@full-setup"

touch "${CHROOT_MNT}/root/IN_THE_MATRIX"
zfs snapshot -r "${ZBM_ROOT}@minor-changes"

rm "${CHROOT_MNT}/root/IN_THE_MATRIX"
rm "${CHROOT_MNT}/root/${CHROOT_SCRIPT##*/}"

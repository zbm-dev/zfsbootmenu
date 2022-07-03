#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

## REMOTE SSH ACCESS

# This script builds a zbm with remote access support via ssh. The image and
# efi executable will contain private host keys and public keys used for
# mutual authentication. It is based on
# https://github.com/zbm-dev/zfsbootmenu/wiki/Remote-Access-to-ZBM

# All keys / settings are placed into ${BUILD_DIR} (the current working
# directory by default). Its contents can be customized as needed.
# They are regenerated if missing.

# Server private keys are generated automatically as needed. It is
# recommended to not reuse existing private keys.
# User authentication for the root account is done via 'authorized_keys'.
# The current users' authorized keys are copied if it is not present.

## ROOT FILESYSTEM

# The root filesystem needs to be unlockable by the primary initrd (the one that
# is started by ZBM), otherwise, the operating system itself will block booting
# and ask for the key again.
# This can be done by using a key file stored in that initrd.
# (Instructions below for ubuntu, but can be adapted to various platforms.)

# This key file will be stored unencrypted in the initramfs, so make sure access
# to it is protected.

# ```
# mkdir -p -m 700 /etc/zfs/keys
# cp passwordfile /etc/zfs/keys/rpool.key
# zfs change-key \
#     -o keylocation=file:///etc/zfs/keys/rpool.key \
#     -o keyformat=passphrase rpool
# update-initramfs -u
# chmod go= /boot
# ```

## USAGE

# To unlock the pool remotely, log in via ssh, then start zfsbootmenu, enter the
# key and continue as usual.

# ```
# ssh root@host -p 222
# zfsbootmenu
# ```


BUILD_DIR=$(realpath "${BUILD_DIR:-${PWD}}")
ZBM_BUILDER=$(realpath "${ZBM_BUILDER:-zbm-builder.sh}")

if [ ! -x "${ZBM_BUILDER}" ]; then
  echo "ERROR: Cannot find build script ${ZBM_BUILDER}, please set \$ZBM_BUILDER"
  exit 1
fi

mkdir -p "${BUILD_DIR}"


## PREPARE SERVER PRIVATE KEYS

# If no local ssh host keys are available, create them
# WARNING: These private keys will be part of the final image!
RS_SSH_KEYTYPES=(rsa ecdsa ed25519)
RS_KEYDIR="${BUILD_DIR}/dropbear"
mkdir -p "${RS_KEYDIR}"

RS_KEYGEN_OPT=(-m PEM -N '' -C "zbm-server-key")
for keytype in "${RS_SSH_KEYTYPES[@]}"; do
  RS_PK_FILE="${RS_KEYDIR}/ssh_host_${keytype}_key"
  [ -f "${RS_PK_FILE}" ] && continue
  ssh-keygen -t "${keytype}" "${RS_KEYGEN_OPT[@]}" -f "${RS_PK_FILE}"
done


## PREPARE AUTHORIZED KEYS

# Attempt to find the authorized_keys file of the original user, instead of
# root, since this script will likely be invoked via sudo. Otherwise, fall
# back to the current user.
if [ -n "${SUDO_USER}" ]; then
  SUDO_HOME=$(eval echo ~"${SUDO_USER}")
fi
if [ -r "${SUDO_HOME}/.ssh/authorized_keys"  ]; then
  RS_AUTH_SRC="${SUDO_HOME}/.ssh/authorized_keys"
else
  RS_AUTH_SRC="${HOME}/.ssh/authorized_keys"
fi

RS_AUTH="${RS_KEYDIR}/authorized_keys"
if [ ! -f "${RS_AUTH}" ]; then
  if [ -r "${RS_AUTH_SRC}" ]; then
    echo "Cannot find ${RS_AUTH}, copying from ${RS_AUTH_SRC}"
    cp -v "${RS_AUTH_SRC}" "${RS_AUTH}"
  else
    echo "ERROR: Cannot find ${RS_AUTH}, and ${RS_AUTH_SRC} is not available, please provide it manually"
    exit 1
  fi
fi


## PREPARE SETTINGS

mkdir -p "${BUILD_DIR}/cmdline.d"
RS_DNC="${BUILD_DIR}/cmdline.d/dracut-network.conf"
if [ ! -f "${RS_DNC}" ]; then
  # ip=dhcp tries to bring up all interfaces
  # ip=single-dhcp stops after bringing up the first
  # See https://www.man7.org/linux/man-pages/man7/dracut.cmdline.7.html
  echo "ip=single-dhcp rd.neednet=1" > "${RS_DNC}"
fi

# Generated config file, not user customizable
mkdir -p "${BUILD_DIR}/dracut.conf.d"
RS_DDC="${BUILD_DIR}/dracut.conf.d/dracut-dropbear.conf"
cat > "${RS_DDC}" <<-EOF
	# Enable dropbear ssh server and pull in network configuration args
	add_dracutmodules+=" crypt-ssh "
	install_optional_items+=" /etc/cmdline.d/dracut-network.conf "
	dropbear_acl=/build/dropbear/authorized_keys
EOF
for keytype in "${RS_SSH_KEYTYPES[@]}"; do
  echo "dropbear_${keytype}_key=/build/dropbear/ssh_host_${keytype}_key" >> "${RS_DDC}"
done


## ZBM BUILDING

"${ZBM_BUILDER}" -b "${BUILD_DIR}" \
  -p dracut-crypt-ssh -p dropbear \
  -v "${BUILD_DIR}/cmdline.d":/etc/cmdline.d:ro \
  "${@}"

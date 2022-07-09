#!/bin/bash
# vim: softtabstop=2 shiftwidth=2 expandtab

## REMOTE SSH ACCESS

# This script builds a zbm with remote access support via ssh. The image and
# efi executable will contain private host keys and public keys used for
# mutual authentication.

# All keys / settings are placed into ${RS_DIR} ('ssh-data' in the current
# working directory by default). Its contents can be customized as needed.
# They are regenerated if missing.

# Server private keys are generated automatically as needed. It is
# recommended to not reuse existing private keys.
# User authentication for the root account is done via 'authorized_keys'.
# The current users' authorized keys are copied if it is not present.

RS_DIR=$(realpath "${RS_DIR:-ssh-data}")
RS_KEYDIR="${RS_DIR}/keys"

mkdir -p "${RS_DIR}"
mkdir -p "${RS_KEYDIR}"


## PREPARE SERVER PRIVATE KEYS

# If no local ssh host keys are available, create them
# WARNING: These private keys will be part of the final image!
RS_SSH_KEYTYPES=(rsa ecdsa)
RS_KEYGEN_OPT=(-m PEM -N '' -C "zbm-server-key")
for keytype in "${RS_SSH_KEYTYPES[@]}"; do
  RS_PK_FILE="${RS_KEYDIR}/ssh_host_${keytype}_key"
  [ -f "${RS_PK_FILE}" ] && continue
  ssh-keygen -t "${keytype}" "${RS_KEYGEN_OPT[@]}" -f "${RS_PK_FILE}"
done


## PREPARE AUTHORIZED KEYS

RS_AUTH="${RS_KEYDIR}/authorized_keys"
if [ ! -f "${RS_AUTH}" ]; then
  echo "Cannot find ${RS_AUTH}, copying from current user"
  cp -v ~/.ssh/authorized_keys "${RS_AUTH}"
fi


## PREPARE SETTINGS

RS_DNC="${RS_DIR}/dracut-network.conf"
if [ ! -f "${RS_DNC}" ]; then
  # ip=dhcp tries to bring up all interfaces
  # ip=single-dhcp stops after bringing up the first
  # See https://www.man7.org/linux/man-pages/man7/dracut.cmdline.7.html
  echo "ip=single-dhcp rd.neednet=1" > "${RS_DNC}"
fi

RS_DDC="${RS_DIR}/dracut-dropbear.conf"
if [ ! -f "${RS_DDC}" ]; then
  cat >> "${RS_DDC}" <<EOF
# Enable dropbear ssh server and pull in network configuration args
add_dracutmodules+=" crypt-ssh "
install_optional_items+=" /etc/cmdline.d/dracut-network.conf "
dropbear_rsa_key=/etc/dropbear/ssh_host_rsa_key
dropbear_ecdsa_key=/etc/dropbear/ssh_host_ecdsa_key
dropbear_acl=/etc/dropbear/authorized_keys
EOF
fi

# zbm-build.sh will copy this into the right place since mounting it into
# /etc/zfsbootmenu/dracut.conf.d breaks the build process
mkdir -p "dracut.conf.d"
cp -f "${RS_DDC}" "dracut.conf.d/"


## ZBM BUILDING

./zbm-builder.sh \
  -p dracut-crypt-ssh -p dropbear \
  -v "${RS_KEYDIR}":/etc/dropbear \
  -v "${RS_DNC}":/etc/cmdline.d/dracut-network.conf \
  "${@}"


# CLEANUP

rm -f "dracut.conf.d/dracut-dropbear.conf"
rmdir --ignore-fail-on-non-empty "dracut.conf.d"

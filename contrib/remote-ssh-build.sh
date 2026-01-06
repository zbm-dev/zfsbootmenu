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
# sed -i '/FILES=/a FILES+=(/etc/zfs/keys/rpool.key) /etc/mkinitcpio.conf
# update-initramfs -u
# chmod go= /boot
# ```

## USAGE

# When you connect via SSH, ZFSBootMenu will launch automatically.
# Enter the encryption key if needed and continue as usual.

# ```
# ssh root@host -p 22
# # ZFSBootMenu starts automatically
# ```

## SSH CONNECTION TIMEOUT

# By default, ZBM with SSH support waits indefinitely for a user to connect.
# Set SSH_TIMEOUT to a number of seconds to enable auto-boot if no SSH login
# occurs within that time. This is useful for unattended reboots with a
# "rescue window" for remote access.

# ```
# SSH_TIMEOUT=60 ./remote-ssh-build.sh
# ```

# With the above, if no SSH login occurs within 60 seconds, boot proceeds.


## SCRIPT ARGUMENTS

# This script forwards arguments to the zbm-builder.sh helper script, but
# overrides any build-directory specification. In addition, the script adds
# arguments to bind-mount \${BUILD_DIR}/cmdline.d and install the `dropbear`
# and `dracut-crypt-ssh` packages inside the container.


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
    # Prepend command="/bin/zfsbootmenu" to each key line so zfsbootmenu
    # automatically starts when a user connects via SSH
    while IFS= read -r line || [ -n "${line}" ]; do
      # Skip empty lines and comments
      if [ -z "${line}" ] || [[ "${line}" == \#* ]]; then
        echo "${line}" >> "${RS_AUTH}"
      # Skip lines that already have command= prefix
      elif [[ "${line}" == command=* ]]; then
        echo "${line}" >> "${RS_AUTH}"
      else
        echo "command=\"/bin/zfsbootmenu\" ${line}" >> "${RS_AUTH}"
      fi
    done < "${RS_AUTH_SRC}"
    echo "Configured authorized_keys to auto-launch zfsbootmenu on SSH login"
  else
    echo "ERROR: Cannot find ${RS_AUTH}, and ${RS_AUTH_SRC} is not available, please provide it manually"
    exit 1
  fi
fi


## PREPARE NETWORK SETTINGS

# Use DHCP for network configuration. The rfc3442-fix.sh hook ensures that
# classless static routes (RFC 3442 / option 121) are parsed correctly,
# which is required for providers like Hetzner that use /32 networks.
#
# Environment variables for network configuration:
#
#   NET_MAC=aa:bb:cc:dd:ee:ff    - Use specific interface by MAC address
#                                  (Creates: ifname=zbmnet0:<mac> ip=zbmnet0:dhcp)
#
#   NET_IFACE=enp0s1             - Use specific interface by name
#                                  (Creates: ip=enp0s1:dhcp)
#
#   NET_IFACE="enp0s1 enp0s2"    - Use multiple interfaces
#                                  (Creates: ip=enp0s1:dhcp ip=enp0s2:dhcp)
#
# If neither is set, defaults to ip=dhcp (all interfaces with DHCP)

mkdir -p "${BUILD_DIR}/cmdline.d"
RS_DNC="${BUILD_DIR}/cmdline.d/dracut-network.conf"
if [ ! -f "${RS_DNC}" ]; then
  # Build network arguments based on configuration
  # See https://www.man7.org/linux/man-pages/man7/dracut.cmdline.7.html
  RS_NET_ARGS=""
  
  if [ -n "${NET_MAC}" ]; then
    # MAC-based interface identification (works regardless of NIC naming)
    # ifname assigns predictable name "zbmnet0" to the interface with this MAC
    RS_NET_ARGS="ifname=zbmnet0:${NET_MAC} ip=zbmnet0:dhcp"
    echo "Network: Using MAC ${NET_MAC} (as zbmnet0)"
  elif [ -n "${NET_IFACE}" ]; then
    # Specific interface(s) by name
    for iface in ${NET_IFACE}; do
      RS_NET_ARGS="${RS_NET_ARGS} ip=${iface}:dhcp"
    done
    echo "Network: Using interface(s): ${NET_IFACE}"
  else
    # Default: DHCP on all interfaces
    RS_NET_ARGS="ip=dhcp"
    echo "Network: DHCP on all interfaces"
  fi
  
  RS_NET_ARGS="${RS_NET_ARGS} rd.neednet=1"
  
  # Add SSH timeout (default: 30 seconds)
  # If no SSH login occurs within this time, boot proceeds automatically
  # Set SSH_TIMEOUT=0 to disable timeout and wait indefinitely
  RS_NET_ARGS="${RS_NET_ARGS} zbm.ssh_timeout=${SSH_TIMEOUT:-30}"
  echo "SSH timeout: ${SSH_TIMEOUT:-30} seconds"
  
  echo "${RS_NET_ARGS}" > "${RS_DNC}"
fi

# Generated config file, not user customizable
mkdir -p "${BUILD_DIR}/dracut.conf.d"
RS_DDC="${BUILD_DIR}/dracut.conf.d/dracut-dropbear.conf"
cat > "${RS_DDC}" <<-EOF
	# Enable dropbear ssh server and pull in network configuration args
	add_dracutmodules+=" crypt-ssh "
	install_optional_items+=" /etc/cmdline.d/dracut-network.conf "
	dropbear_acl=/build/dropbear/authorized_keys
	dropbear_port="22"
EOF
for keytype in "${RS_SSH_KEYTYPES[@]}"; do
  echo "dropbear_${keytype}_key=/build/dropbear/ssh_host_${keytype}_key" >> "${RS_DDC}"
done

# Install patched dhclient-script with RFC 3442 fix
# Dracut's dhclient-script has a buggy parse_option_121() that doesn't validate
# arguments, causing errors on networks like Hetzner. This installs a patched version.
# We use a dracut module with prefix 30 to load BEFORE 35network-legacy.
RS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${RS_SCRIPT_DIR}/network-hooks/dhclient-script.patched" ]; then
  # Copy patched script to sbin directory (mounted at /sbin/dhclient-script in container)
  mkdir -p "${BUILD_DIR}/sbin"
  cp "${RS_SCRIPT_DIR}/network-hooks/dhclient-script.patched" "${BUILD_DIR}/sbin/dhclient-script"
  chmod 755 "${BUILD_DIR}/sbin/dhclient-script"
  
  # Copy the dracut module (prefix 30 loads before 35network-legacy)
  mkdir -p "${BUILD_DIR}/dracut-modules/30rfc3442fix"
  cp "${RS_SCRIPT_DIR}/dracut-modules/30rfc3442fix/module-setup.sh" \
     "${BUILD_DIR}/dracut-modules/30rfc3442fix/"
  
  # Add dracut config to load our module
  RS_NETFIX="${BUILD_DIR}/dracut.conf.d/network-fix.conf"
  cat > "${RS_NETFIX}" <<-'EOF'
	# Load rfc3442fix module (installs patched dhclient-script before network-legacy)
	add_dracutmodules+=" rfc3442fix "
EOF
  echo "Patched dhclient-script installed"
fi

## ZBM BUILDING

# Separate arguemnts into those for the helper and those for the container
HELPER_ARGS=( )
BUILDER_ARGS=( )

_builder=""
for _arg in "$@"; do
  # Pulling helper arguments first
  if [ -z "${_builder}" ]; then
    # If the argument is "--", drop it and switch to container args
    if [ "${_arg}" = "--" ]; then
      _builder="yes"
      continue
    fi

    HELPER_ARGS+=( "${_arg}" )
  else
    BUILDER_ARGS+=( "${_arg}" )
  fi
done

# Build using local ZFSBootMenu source tree (includes SSH timeout feature)
ZBM_SOURCE_DIR="$(cd "$(dirname "${ZBM_BUILDER}")" && pwd)"

"${ZBM_BUILDER}" "${HELPER_ARGS[@]}" -b "${BUILD_DIR}" -l "${ZBM_SOURCE_DIR}" \
  -O -v -O "${BUILD_DIR}/cmdline.d:/etc/cmdline.d:ro" \
  -O -v -O "${BUILD_DIR}/sbin/dhclient-script:/sbin/dhclient-script:ro" \
  -O -v -O "${BUILD_DIR}/dracut-modules/30rfc3442fix:/usr/lib/dracut/modules.d/30rfc3442fix:ro" \
  -- "${BUILDER_ARGS[@]}" -p dracut-crypt-ssh -p dropbear


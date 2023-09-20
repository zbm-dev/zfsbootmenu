#!/bin/bash

## NOTE: This hook is obsolete; the recommended way to manage key caching is
## with the org.zfsbootmenu:keysource property described in zfsbootmenu(7).

## This setup hook attempts to cache keyfiles for ZFS encryptionroots in the
## initramfs, reducing the number of password requests made by ZFSBootMenu.
## ZFSBootMenu will attempt to mount the default boot environment (i.e.,
## whichever boot environment will boot automatically) and, for each
## keylocation that provides a file:// URI, copy the file from the
## corresponding location in the default BE (if it exists) to the expected
## location within the initramfs.
##
## To use, put this script somewhere, make sure it is executable, and add the
## path to the `zfsbootmenu_setup` space-separated list with, e.g.,
##
##     zfsbootmenu_setup+=" <path to script> "
##
## in a dracut.conf(5) file inside the directory specified for the option
## `Global.DracutConfDir` in the ZFSBootMenu `config.yaml`.
##
## CAVEATS
## 1. As ZFSBootMenu runs in an initramfs and does not enable swap, I do not
##    believe that copying key files to the initramfs will allow the contents
##    to be written to unencrypted storage. However, I CANNOT GUARANTEE THIS.
##    If you are concerned about key security, make sure you have a thorough
##    understanding of the control flow of ZFSBootMenu and this hook before
##    enabling it. You have been warned!
##
## 2. Because this only cares about the default BE as a key source, this will
##    not cache any key files defined in other BEs.
##
## 3. If you have different BEs that each hold key files with different
##    contents from, but conflicting names with, some keys in the default
##    environment, any BEs that depend on the non-default keys will be
##    inaccessible to ZFSBootMenu when this hook is enabled. ZFSBootMenu will
##    find the cached key and attempt (unsuccessfully) to use it on the
##    affected BEs rather than forcing a password prompt as it would were the
##    keys not cached. (This is probably an inadvisable configuration anyway.
##    If you use different keys, just give them unique paths.)

# shellcheck disable=SC1091
[ -r /lib/zfsbootmenu-core.sh ] && . /lib/zfsbootmenu-core.sh

# Make sure key environment variables are defined
[ -n "${BOOTFS}" ] || exit 0

# Try to mount the bootfs to search for keys
load_key "${BOOTFS}" || exit 0
mnt="$(mount_zfs "${BOOTFS}")" || exit 0

# Make sure to capture unmount
# shellcheck disable=SC2064
trap "umount '${mnt}'" EXIT

while read -r keyloc; do
	# Make sure key location is a file:// URI, strip the scheme
	keyfile="${keyloc#file://}"
	[ "${keyloc}" = "${keyfile}" ] && continue

	# If the keyfile already exists, there is nothing left to do
	[ -f "${keyfile}" ] && continue

	# Make sure the file exists on the bootfs
	[ -f "${mnt}/${keyfile}" ] || continue

	# Create the key directory if needed
	keydir="${keyfile%/*}"
	[ "${keydir}" = "${keyfile}" ] && keydir=
	[ -n "${keydir}" ] && mkdir -p "${keydir}"

	# Copy the key in place
	cp "${mnt}/${keyfile}" "/${keyfile}"
	# This is irrelevant; only root exists in the initramfs
	chmod 000 "/${keyfile}"
done <<< "$( zfs list -H -o keylocation )"

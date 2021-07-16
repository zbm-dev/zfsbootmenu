#!/bin/sh

error() {
	echo ERROR: "$@"
	exit 1
}

# shellcheck disable=SC2010
if ls -Aq /zbm | grep -q . >/dev/null 2>&1; then
	# If /zbm is not empty, make sure it looks like it has what we need
	[ -d /zbm/90zfsbootmenu ] || error "missing path /zbm/90zfsbootmenu"
	[ -d /zbm/contrib/docker ] || error "missing path /zbm/contrib/docker"
	[ -x /zbm/bin/generate-zbm ] || error "missing executable /zbm/bin/generate-zbm"
else
	# If /zbm is empty, clone the upstream repo into it
	xbps-install -Sy git
	git clone --depth=1 https://github.com/zbm-dev/zfsbootmenu /zbm
fi

# Make sure that dracut can find the ZFSBootMenu module
ln -sf /zbm/90zfsbootmenu /usr/lib/dracut/modules.d/90zfsbootmenu

BUILDROOT="/zbm/contrib/docker"

if [ ! -e "${BUILDROOT}/config.yaml" ]; then
	# If there is no provided config, copy the default
	cp "${BUILDROOT}/config.yaml.default" "${BUILDROOT}/config.yaml"
fi

if [ -r "${BUILDROOT}/hostid" ]; then
	# If a hostid is provided in the build root, use it
	cp "${BUILDROOT}/hostid" /etc/hostid
else
	# Otherwise, make sure there is no hostid file
	rm -f /etc/hostid
fi

if [ -r "${BUILDROOT}/zpool.cache" ]; then
	# If a zpool cache is provided, use it
	mkdir -p /etc/zfs
	cp "${BUILDROOT}/zpool.cache" /etc/zfs/zpool.cache
else
	# Otherwise, make sure there is no cache file
	rm -f /etc/zfs/zpool.cache
fi

exec /zbm/bin/generate-zbm --config "${BUILDROOT}/config.yaml"

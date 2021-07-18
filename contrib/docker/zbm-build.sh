#!/bin/sh

error() {
	echo ERROR: "$@"
	exit 1
}

# shellcheck disable=SC2010
if ls -Aq /zbm | grep -q . >/dev/null 2>&1; then
	# If /zbm is not empty, make sure it looks like it has what we need
	[ -d /zbm/90zfsbootmenu ] || error "missing path /zbm/90zfsbootmenu"
	[ -x /zbm/bin/generate-zbm ] || error "missing executable /zbm/bin/generate-zbm"
else
	# If /zbm is empty, clone the upstream repo into it
	xbps-install -Sy git
	git clone https://github.com/zbm-dev/zfsbootmenu /zbm

	# If the run specifies $ZBM_COMMIT_HASH, check out the hash
	# Get a default value for ZBM_COMMIT_HASH from /etc/zbm-commit-hash
	if [ -z "${ZBM_COMMIT_HASH}" ] && [ -r "/etc/zbm-commit-hash" ]; then
		read -r ZBM_COMMIT_HASH < /etc/zbm-commit-hash
	fi

	if [ -n "${ZBM_COMMIT_HASH}" ]; then
		if ! ( cd /zbm && git checkout -q "${ZBM_COMMIT_HASH}" ); then
			error "failed to checkout commit, aborting"
		fi
	fi
fi

BUILDROOT="${1:-/zbm/contrib/docker}"
[ -d "${BUILDROOT}" ] || error "Build root does not appear to exist"

# Make sure that dracut can find the ZFSBootMenu module
ln -sf /zbm/90zfsbootmenu /usr/lib/dracut/modules.d/90zfsbootmenu

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

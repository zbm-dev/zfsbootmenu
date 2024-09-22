#!/bin/sh

set -e

## ZBM Builder Kernel Installer
#
# This rc.d script for ZFSBootMenu build containers will install a Void kernel
# and headers specified in the environment variable ZFSBOOTMENU_KERNEL_SERIES.
# The value of the variable should take the form `linuxY.Z` for major version Y
# and minor version Z; the most up-to-date version released for Void in that
# series will be installed. In addition, this script will install the Void dkms
# package and its dependencies to allow the ZFS kernel module to be built for
# the kernel.
#
# If the environment variable ZFSBOOTMENU_KERNEL_SERIES is not defined, the
# version currently recommended by Void Linux (as indicated by the version of
# the `linux` meta-package) will be selected.
#
## USAGE
#
# The ZFSBootMenu build container entrypoint will invoke all executables found
# in the `rc.pre.d` and `rc.d` subdirectories of its build root. Simply install
# this script to one of these paths (the distinction is not relevant for this
# operation) and run the builder.
#
# The environment variable can be specified using the `--env` argument to
# `podman run` or `docker run`. When using the `zbm-builder.sh` convenience
# wrapper, its `-O` flag can be used to pass `--env` to the container runtime.
# For example,
#
#     zbm-builder.sh -O --env=ZFSBOOTMENU_KERNEL_SERIES=linux6.10
#
# When the container is run by the `zbm-builder.sh` convenience wrapper, the
# build directory is the path provided to the `-b` argument of the wrapper (and
# is, by default, the current working directory). When the container is invoked
# manually, the build directory is the path specified by the `-b` argument of
# the entrypoint (and is, by default, the path `/build`).
#
# In the default configuration, ZFSBootMenu will be built with the latest
# installed kernel. If this script is used to select a kernel series older than
# one preinstalled in the build image, a custom config.yaml may be required in
# the build root to create a ZFSBootMenu image using the newly installed
# kernel.
#
## NOTE
#
# This script will not attempt to update packages. In particular, if a newer
# version of the `zfs` package is desired, the container should be run with the
# flags `-u -u` (yes, twice) to update packages. Alternatively, uncomment the
# command
#
#     xbps-install -uy zfs
#
# near the end of this script.

# Make sure XBPS and the repositories are up to date
xbps-install -Suy xbps

if [ -z "${ZFSBOOTMENU_KERNEL_SERIES}" ]; then
	# Use the linux meta-package to identify a default series
	ZFSBOOTMENU_KERNEL_SERIES="$(
		xbps-query -Rp pkgver linux | xargs xbps-uhelper getpkgversion
	)" || ZFSBOOTMENU_KERNEL_SERIES=""

	if [ -z "${ZFSBOOTMENU_KERNEL_SERIES}" ]; then
		echo "ERROR: unable to determine ZFSBOOTMENU_KERNEL_SERIES" >&2
		exit 1
	fi

	ZFSBOOTMENU_KERNEL_SERIES="linux${ZFSBOOTMENU_KERNEL_SERIES%_*}"
fi

xbps-install -uy dkms \
	"${ZFSBOOTMENU_KERNEL_SERIES}" "${ZFSBOOTMENU_KERNEL_SERIES}-headers"

# To update zfs, uncomment this line
#xbps-install -uy zfs

# Make sure that the kernel module is built
xbps-reconfigure -f zfs

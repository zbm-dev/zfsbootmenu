# syntax=docker/dockerfile:1.4
#
# This Dockerfile creates a container that will create an EFI executable and
# separate kernel/initramfs components from a ZFSBootMenu repository. The
# container will pre-populate its /zbm directory with a clone of the master
# branch of the upstream ZFSBootMenu branch and build the images from that.
#
# To use a different ZFSBootMenu repository or version, bind-mound the
# repository you want on /zbm inside the container.
#
# Note - this Dockerfile depends on Docker >= 23 and the docker buildx plugin.

# Use the official Void Linux container
FROM ghcr.io/void-linux/void-glibc-full
LABEL org.opencontainers.image.authors="ZFSBootMenu Team, https://zfsbootmenu.org"

ARG XBPS_REPOS="https://repo-fastly.voidlinux.org/current"

# Include the specified Void Linux kernel series in the image; kernel
# series take the form linux<major>.<minor>
#
# Default: linux5.10 linux5.15 linux6.1
# (multiple entries must be seperated by spaces)
ARG KERNELS="linux5.10 linux5.15 linux6.1"
# Update repos and install kernels and base dependencies.

# Run the following within an external cache (/var/cache/xbps) for the
# package manager; so when this layer is rebuilt, at least you save
# some bandwidth.
RUN --mount=type=cache,target=/var/cache/xbps <<-EOF
	if [ -z "${KERNELS}" ]; then
		echo "ARG KERNELS must contain a value"
		exit 1
	fi

	mkdir -p /etc/xbps.d
	for _repo in ${XBPS_REPOS}; do
		echo "repository=${_repo}" >> /etc/xbps.d/00-custom-repos.conf
	done

	# Ensure everything is up-to-date
	xbps-install -Suy xbps && xbps-install -Suy

	# Prefer an LTS version over whatever Void thinks is current
	echo "ignorepkg=linux" > /etc/xbps.d/10-nolinux.conf
	echo "ignorepkg=linux-headers" >> /etc/xbps.d/10-nolinux.conf

	# Prevent initramfs kernel hooks from being installed
	echo "noextract=/usr/libexec/mkinitcpio/*" > /etc/xbps.d/15-noinitramfs.conf
	echo "noextract=/usr/libexec/dracut/*" >> /etc/xbps.d/15-noinitramfs.conf

	for _kern in ${KERNELS}; do
		kern_headers="${kern_headers} ${_kern}-headers"
	done

	# Install ZFSBootMenu dependencies and components necessary to build images
	zbm_deps="$(xbps-query -Rp run_depends zfsbootmenu)"
	xbps-install -y ${KERNELS} ${kern_headers} ${zbm_deps} \
		zstd systemd-boot-efistub curl yq-go bash kbd \
		dracut mkinitcpio dracut-network gptfdisk iproute2 iputils parted \
		dosfstools e2fsprogs efibootmgr cryptsetup openssh util-linux kpartx

	# Remove headers and development toolchain, but keep binutils for objcopy
	echo "ignorepkg=dkms" > /etc/xbps.d/10-nodkms.conf
	xbps-pkgdb -m manual binutils
	xbps-remove -Roy dkms ${kern_headers}
	EOF

# ZFSBootMenu commit hash, tag or branch name used by
# default to build ZFSBootMenu images (default: master)
ARG ZBM_COMMIT_HASH=
# Record a commit hash if one was provided
RUN [ -z "${ZBM_COMMIT_HASH}" ] || echo "${ZBM_COMMIT_HASH}" > /etc/zbm-commit-hash

# Include the specified Void Linux package in the image
# (multiple entries must be seperated by spaces)
ARG PACKAGES=
# Run ${PACKAGES} install in seperate layer so that the zfs dkms packages
# are not rebuilt when ${PACKAGES} change. reuse. Additionally: use xbps cache.
# Install ZFSBootMenu dependencies and components necessary to build images
RUN --mount=type=cache,target=/var/cache/xbps \
	[ -z "${PACKAGES}" ] || xbps-install -y ${PACKAGES}

# Free space in image
RUN rm -f /var/cache/xbps/*

ARG ZBM_BUILDER=build-init.sh
COPY --chmod=755 ${ZBM_BUILDER} /
# Run the build script with no arguments by default
ENTRYPOINT [ "/${ZBM_BUILDER}" ]

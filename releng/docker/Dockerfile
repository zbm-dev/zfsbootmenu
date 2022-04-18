# This Dockerfile creates a container that will create an EFI executable and
# separate kernel/initramfs components from a ZFSBootMenu repository. The
# container will pre-populate its /zbm directory with a clone of the master
# branch of the upstream ZFSBootMenu branch and build the images from that.
#
# To use a different ZFSBootMenu repository or version, bind-mound the
# repository you want on /zbm inside the container.

# Use the official Void Linux container
FROM voidlinux/voidlinux:latest
ARG ZBM_COMMIT_HASH

# Ensure everything is up-to-date
RUN xbps-install -Suy xbps && xbps-install -uy

# Prefer an LTS version over whatever Void thinks is current
RUN echo "ignorepkg=linux" > /etc/xbps.d/10-nolinux.conf \
	&& echo "ignorepkg=linux-headers" >> /etc/xbps.d/10-nolinux.conf

# Install components necessary to build the image
RUN xbps-query -Rp run_depends zfsbootmenu | xargs xbps-install -y
RUN xbps-install -y linux5.10 linux5.10-headers \
	zfs gummiboot-efistub curl yq-go bash kbd terminus-font dracut mkinitcpio cryptsetup

# Remove headers and massive dkms development toolchain; binutils
# provides objcopy, which is necessary for UEFI bundle creation
RUN xbps-pkgdb -m manual binutils
RUN echo "ignorepkg=dkms" > /etc/xbps.d/10-nodkms.conf
RUN xbps-remove -Roy linux5.10-headers dkms && rm -f /var/cache/xbps/*

# Record a commit hash if one was provided
RUN if [ -n "${ZBM_COMMIT_HASH}" ]; then echo "${ZBM_COMMIT_HASH}" > /etc/zbm-commit-hash; fi

# Copy the build script
COPY zbm-build.sh /zbm-build.sh

# Run the build script with no arguments by default
ENTRYPOINT [ "/zbm-build.sh" ]
CMD [ ]

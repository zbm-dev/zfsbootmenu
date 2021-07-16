# This Dockerfile creates a container that will create an EFI executable and
# separate kernel/initramfs components from a ZFSBootMenu repository. The
# container will pre-populate its /zbm directory with a clone of the master
# branch of the upstream ZFSBootMenu branch and build the images from that.
#
# To use a different ZFSBootMenu repository or version, bind-mound the
# repository you want on /zbm inside the container.

# Use the official Void Linux container
FROM voidlinux/voidlinux:latest

# Ensure everything is up-to-date
RUN xbps-install -Suy xbps && xbps-install -uy

# Install components necessary to build the image
RUN xbps-query -Rp run_depends zfsbootmenu | xargs xbps-install -y
RUN xbps-install -y linux linux-headers zfs gummiboot-efistub

# Copy the build script
COPY zbm-build.sh /zbm-build.sh

# To replace the default ZFSBootMenu tree, bind-mount over /zbm
VOLUME /zbm

# Make sure a configuration exists or copy the default, then create the images
CMD /zbm-build.sh

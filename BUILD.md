# Customized ZFSBootMenu Images from Build Containers - A Quick Start Guide

## Introduction

Official ZFSBootMenu release assets are built within OCI containers based on the [zbm-builder image](https://github.com/zbm-dev/zfsbootmenu/pkgs/container/zbm-builder). The image is built atop Void Linux and provides a predictable environment without the need to install ZFSBootMenu or its dependencies on the host system.

The `zbm-builder.sh` script provides a front-end for integrating custom ZFSBootMenu configurations into the build container without the complexity of directly controlling the container runtime.

Users wishing to build custom ZFSBootMenu images should be familiar with the core concepts of ZFSBootMenu as outlined in the [project README](README.md). For those interested, the [container README](releng/docker/README.md) provides more details on the operation of the ZFSBootMenu build container. However, `zbm-builder.sh` seeks to abstract away many of the details discussed in that document.

## Dependencies

To build ZFSBootMenu images from a build container, one of [`podman`](https://podman.io) or [`docker`](https://www.docker.com) is required. The development team prefers `podman`, but `docker` may generally be substituted without consequence.

If a custom build container is desired, [`buildah`](https://buildah.io) and `podman` are generally required. A [`Dockerfile`](releng/docker/Dockerfile) is provided for convenience, but feature parity with the `buildah` script is not guaranteed. The [container README](releng/docker/README.md) provides more information about the process of creating a custom build image.

### Podman

Install `podman` and `buildah` (if desired) using the package manager in your distribution:

- On Void, `xbps-install podman buildah`
- On Arch or its derivatives, `pacman -S podman buildah`
- On Debian or its derivatives, `apt-get install podman buildah`

It is possible to configure `podman` for rootless container deployment. Consult the [tutorial](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md) for details.

### Docker

Install `docker` using the package manager in your distribution:

- On Void, `xbps-install docker`
- On Arch or its derivatives, `pacman -S docker`
- On Debian or its derivatives, `apt-get install docker`

Non-root users that should be permitted to work with Docker images and containers should belong to the `docker` groups. For example,

```sh
usermod -a -G docker zbmuser
```

will add `zbmuser` to the `docker` group on systems that provide the `usermod` program.

### Build Script

The `zbm-builder.sh` script requires nothing more than functional installations of `bash` and one of `podman` or `docker`. Simply download a copy of the script to a convenient directory.

> Advanced users may wish to build images from a local copy of the ZFSBootMenu source tree. To make this possible, either fetch and unpack a source tarball or clone the git repository locally.

## Building a ZFSBootMenu Image

To build a default image, invoke `zbm-builder.sh` with no arguments. For example, from the directory that contains the script, run

```sh
./zbm-builder.sh
```

to produce a default kernel/initramfs pair in the `./build/components` subdirectory.

The default behavior of `zbm-builder.sh` will:

1. Pull the default builder image, `ghcr.io/zbm-dev/zbm-builder:latest`.
2. If `./hostid` does not exist, copy `/etc/hostid` (if it exists) to `./hostid`.
3. If `./zpool.cache` does not exist, copy `/etc/zfs/zpool.cache` to `./zpool.cache`.
4. Spawn an ephemeral container from the builder image and run its build process:
    1. Bind-mount the working directory into the container to expose local configurations to the builder
    2. If `./config.yaml` exists, inform the builder to use that custom configuration instead of the default
    3. Run the internal build script to produce output in the `./build` subdirectory

### Customizing Images

A custom `config.yaml` may be provided in the working directory to override the
default ZFSBootMenu configuration. The build container runs its build script
from the working directory on the host. Therefore, relative paths in a custom
`config.yaml` will be interpreted relative to the working directory when
`zbm-builder.sh` is invoked.

> The internal build script **always** overrides the output paths for ZFSBootMenu components and UEFI executables to ensure that the images will reside in the `./build` subdirectory upon completion. Relative paths are primarily useful for specifying local `dracut` or `mkinitcpio` configuration paths.

More advanced users may wish to alter the build process itself. Some control over the build process is exposed through command-line options that are described in the output of

```sh
zbm-builder.sh -h
```

Before adjusting these command-line options, seek a thorough understanding of the [image build process](releng/docker/README.md) and the command sequence of `zbm-builder.sh` itself.

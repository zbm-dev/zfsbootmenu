# Customized ZFSBootMenu Images from Build Containers - A Quick Start Guide

## Introduction

Official ZFSBootMenu release assets are built within OCI containers based on the [zbm-builder image](https://github.com/zbm-dev/zfsbootmenu/pkgs/container/zbm-builder). The image is built atop Void Linux and provides a predictable environment without the need to install ZFSBootMenu or its dependencies on the host system.

The `zbm-builder.sh` script provides a front-end for integrating custom ZFSBootMenu configurations into the build container without the complexity of directly controlling the container runtime.

Users wishing to build custom ZFSBootMenu images should be familiar with the core concepts of ZFSBootMenu as outlined in the [project README](../README.md). For those interested, the [container README](../releng/docker/README.md) provides more details on the operation of the ZFSBootMenu build container. However, `zbm-builder.sh` seeks to abstract away many of the details discussed in that document.

## Dependencies

To build ZFSBootMenu images from a build container, one of [`podman`](https://podman.io) or [`docker`](https://www.docker.com) is required. The development team prefers `podman`, but `docker` may generally be substituted without consequence.

If a custom build container is desired, [`buildah`](https://buildah.io) and `podman` are generally required. A [`Dockerfile`](../releng/docker/Dockerfile) is provided for convenience, but feature parity with the `buildah` script is not guaranteed. The [container README](../releng/docker/README.md) provides more information about the process of creating a custom build image.

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

to produce a default kernel/initramfs pair in the `./build` subdirectory.

The default behavior of `zbm-builder.sh` will:

1. Pull the default builder image, `ghcr.io/zbm-dev/zbm-builder:latest`.
2. If `./hostid` does not exist, copy `/etc/hostid` (if it exists) to `./hostid`.
3. Spawn an ephemeral container from the builder image and run its build process:
    1. Bind-mount the working directory into the container to expose local configurations to the builder
    2. If `./config.yaml` exists, inform the builder to use that custom configuration instead of the default
    3. Run the internal build script to produce output in the `./build` subdirectory

### Custom ZFSBootMenu Hooks

ZFSBootMenu supports [custom hooks](pod/zfsbootmenu.7.pod#options-for-dracut) in three stages:

1. `early_setup` hooks run after the `zfs` kernel driver has been loaded, but before ZFSBootMenu attempts to import any pools.
2. `setup` hooks run after pools are imported, right before ZFSBootMenu will either boot a default environment or present a menu.
3. `teardown` hooks run immediately before ZFSBootMenu will `kexec` the kernel for the selected environment.

When `zbm-builder.sh` runs, it will identify custom hooks as executable files in the respective subdirectories of its build directory:

1. `hooks.early_setup.d`
2. `hooks.setup.d`
3. `hooks.teardown.d`

For each hook directory that contains at least one executable file, `zbm-builder.sh` will write custom configuration snippets for `dracut` and `mkinitcpio` that will include these files in the output images.

> The `mkinitcpio` configuration prepared by `zbm-builder.sh` consists of snippets installed in a `mkinitcpio.d` subdirectory of the build directory. The [default `mkinitcpio` configuration](../etc/zbm-builder/mkinitcpio.conf) includes a loop to source these snippets.

### Fully Customizing Images

The entrypoint for the ZFSBootMenu implements a [tiered configuration approach](../releng/docker/README.md#zfsbootmenu-configuration-and-execution) that allows default configurations to be augmented or replaced with local configurations in the build directory. A custom `config.yaml` may be provided in the working directory to override the default ZFSBootMenu configuration; configuration snippets for `dracut` or `mkinitcpio` can be placed in the `dracut.conf.d` and `mkinitcpio.conf.d` subdirectories, respectively. For `mkinitcpio` configurations, a complete `mkinitcpio.conf` can be placed in the working directory to override the standard configuration.

> The standard `mkinitcpio.conf` in the ZBM build container contains customizations to source snippets in the `mkinitcpio.conf.d`. This is not standard behavior for `mkinitcpio`. If the primary `mkinitcpio.conf` is overridden, this logic may need to be replicated. It is generally better to rely on the default configuration and override portions in `mkinitcpio.conf.d`.

The build container runs its build script from the working directory on the host. In general, relative paths in custom configuration files are generally acceptable and refer to locations relative to the build directory. If absolute paths are preferred or required for some configurations, note that the build directory will be mounted as `/build` in the container.

> The internal build script **always** overrides the output paths for ZFSBootMenu components and UEFI executables to ensure that the images will reside in a specified output directory (or, by default, a `build` subdirectory of build directory) upon completion. Relative paths are primarily useful for specifying local `dracut` or `mkinitcpio` configuration paths.

More advanced users may wish to alter the build process itself. Some control over the build process is exposed through command-line options that are described in the output of

```sh
zbm-builder.sh -h
```

Before adjusting these command-line options, seek a thorough understanding of the [image build process](../releng/docker/README.md) and the command sequence of `zbm-builder.sh` itself.

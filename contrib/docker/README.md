# Containerized Image Building

Files in this directory provide a means for creating a container that is
capable of building ZFSBootMenu kernel and initramfs components as well as a
standalone UEFI bundle. The container image is built atop Void Linux and
provides the basic components necessary to build an image from an arbitrary
ZFSBootMenu repository, including a build script that runs by default when the
container is started.

These images build and run with both Docker and Podman. Podman is recommended
as it provides daemon-free container management and allows containers to run as
unprivileged users. Sample commands below refer to the `podman` command.
However, because `podman` and `docker` have compatible command-line interfaces,
the commands should work just as well by substituting `docker` for `podman`.

# Creating a ZFSBootMenu Builder Image

The provided `Dockerfile` automates creation of the ZFSBootMenu builder image.
From this directory, simply run

```sh
podman build -t zbm .
```

to create an image named `zbm`. (Podman automatically prepends `localhost` and
appends `:latest` to unqualified tags, so the full image name will be
`localhost/zbm:latest`.) Any suitable tag may be substituted for `zbm`.

The resulting image contains all ZFSBootMenu prerequisites. Hard dependencies
of ZFSBootMenu are determined by querying the Void Linux `zfsbootmenu` package,
which will generally provide up-to-date information. In rare cases, a build
from the master branch may introduce new requirements that are not reflected in
the latest release version packaged for Void; manually editing the `Dockerfile`
to add new dependencies may be necessary until a new release is packaged.

The builder image does **not** contain a ZFSBootMenu installation or a copy of
the upstream git repository. Instead, the image contains a build script,
installed as `/zbm-build.sh`, that runs by default. The script ensures that a
ZFSBootMenu repository is available in a running container and invokes
`generate-zbm` to build images.

# Running a ZFSBootMenu Builder Container

When running a container from the ZFSBootMenu builder image, it is generally
expected that some compatible volume (generally, a local directory) will be
bind-mounted as a volume at the path `/zbm` inside the container. This volume
may either be empty or contain a pre-existing ZFSBootMenu source tree.
Specifically, if the volume is not empty, it must contain the following
components of the ZFSBootMenu repository:

- `90zfsbootmenu`, the Dracut module encapsulating ZFSBootMenu functionality;
- `bin/generate-zbm`, the executable script that creates ZFSBootMenu images;
- `contrib/docker`, providing either `config.yaml` or `config.yaml.default`.

If the build script finds the volume mounted at `/zbm` empty, it will install
the `git` package and clone the master branch of the upstream ZFSBootMenu
repository. This makes the image capable of producing default images without
needing a local clone of the repository. To build anything but the head commit
of the upstream master branch, clone the repository, checkout an aribtrary
commit or make local changes, and mount that repository at `/zbm`.

## Contents of `contrib/docker`

The build script expects to find a valid ZFSBootMenu configuration file at
`/zbm/contrib/docker/config.yaml` within the container. If this file does not
exist, the file `/zbm/contrib/docker/config.yaml.default` will be copied to the
expected location. At least one of these files must exist or the build script
will fail. The default configuration will store images in the directory
`contrib/docker/build`, which will be created by `generate-zbm` if it does not
already exist.

Builder containers do not have access to local files `/etc/zfs/zpool.cache` or
`/etc/hostid`. If one or both of these components are desired in the output
image (for example, to ensure consistency with the build host), copy the
desired files to `contrib/docker/zpool.cache` or `contrib/docker/hostid`,
respectively. If the build script finds these files, it will copy them into the
container where the ZFSBootMenu Dracut module expects to find them. If one of
these files is missing, any corresponding file already installed in the
container will be *removed*.

## Build Examples

To use the previously created `zbm` image to produce ZFSBootMenu files from the
default configuration using a local ZFSBootMenu repository `/sw/zfsbootmenu`,
simply run

```sh
podman run -v /sw/zfsbootmenu:/zbm /zbm
```

After some console output, the container should terminate and the directory
`/sw/zfsbootmenu/contrib/docker/build` should contain the UEFI bundle
`vmlinuz.EFI` as well as the components `vmlinuz-bootmenu` (a stock Void Linux
kernel) and corresponding ZFSBootMenu initramfs `initramfs-bootmenu.img`.

In the default configuration, the ZFSBootMenu images probably contain an
arbitrary `/etc/hostid` that likely does not agree with the corresponding file
on the host. To make sure that the hostid within the images remains consistent
with the build host, first copy the file from the host to the `contrib/docker`
directory:

```sh
cp /etc/hostid /sw/zfsbootmenu/contrib/docker/hostid
podman run -v /sw/zfsbootmenu:/zbm /zbm
```

# Using Docker Compose

The file `docker-compose.yml` defines a Docker Compose service that will create
a ZFSBootMenu builder image and mount the parent repository (at path `../..`)
at `/zbm` in the build container. To use this service, simply run

```sh
docker-compose up
```

from this directory.

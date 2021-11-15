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

The script `image-build.sh` uses `buildah` to construct a ZBM builder image.
This is the preferred way to construct the image and may, in the future,
provide features not available with a `podman build` workflow. The script
requires a single argument, the tag to use when naming the image.

An optional second argument is a Git commit-like reference (a hash or tag) that
will be recorded as `/etc/zbm-commit-hash` in the image. The contents of this
file are used to checkout a specific state of the ZFSBootMenu repository. If
the tag is unspecified on the command line, the build script will attempt to
capture a reference to the current HEAD commit if the image is built in an
active git repository. If a commit-like name is not provided and cannot be
discovered, no default will be recorded and containers will attempt to build
from the current `master`.

The `image-build.sh` script expects to be run from the root of the ZFSBootMenu
tree by default. From there, the path `releng/docker/zbm-build.sh` defines the
entrypoint for build containers. To run the `image-build.sh` script from
another directory, simply set the `ZBM_BUILDER` environment variable to the
location of the `zbm-build.sh` script to use.

For those without access to `buildah`, the `Dockerfile` will also create of a
ZFSBootMenu builder image. From this directory, simply run

```sh
podman build --squash -t zbm .
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
the upstream git repository. Instead, the entrypoint `/zbm-build.sh` will fetch
a ZFSBootMenu archive when the container is instantiated (or allow a local copy
to be bind-mounted) and, as noted above, attempt to check out a specific commit
based on the contents of `/etc/zbm-commit-hash`.

# Running a ZFSBootMenu Builder Container

When running a container from the ZFSBootMenu builder image, it is generally
expected that some compatible volume (generally, a local directory) will be
bind-mounted as a volume at the path `/zbm` inside the container. This volume
may either be empty or contain a pre-existing ZFSBootMenu source tree.
Specifically, if the volume is not empty, it must contain the following
components of the ZFSBootMenu repository:

- `90zfsbootmenu`, the Dracut module encapsulating ZFSBootMenu functionality;
- `bin/generate-zbm`, the executable script that creates ZFSBootMenu images;

If the build script finds the volume mounted at `/zbm` empty, it will fetch an
archive of the official ZFSBootMenu repository on github.com. This makes the
image capable of producing default images without needing a local clone of the
repository. The specific commit, tag or branch to fetch can be specified at
container run time.

## Command-Line Arguments and Environment Variables

The build script accepts several command-line arguments or environment
variables that override its default behavior. Run the container with the `-h`
command-line argument to see a summary of build options and their default
options. The options are:

- `$BUILDROOT` specifies a default root for image builds. The build root is
  expected to hold a default default configuration file and output directory,
  as well as optional hostid and pool cache files. If an output directory,
  specific configuration and (when appropriate) hostid or pool cache are
  specified, then `$BUILDROOT` is not relevant.

  The environment variable or default can be overridden with the `-b` option.

- `$ZBMCONF` specifies the in-container path to a specific configuration file.
  The build script will override any `ImageDir` paths and remove any
  `Global.BootMountPoint` option but otherwise uses the configuration as-is.A

  The environment variable or default can be overridded with the `-c` option.

- `$ZBMOUTPUT` specifies the in-container path to an output directory. As noted
  above, the build script overrides any `ImageDir` path in a configuration,
  pointing it instead to a temporary output directory. After the script
  successfully runs `generate-zbm`, it will copy any artifacts from the
  temporary build directory to `$ZBMOUTPUT`.

  The environment variable or default can be overridded with the `-o` option.

- `$HOSTID` specifies the in-container path to a hostid file. If this file is
  specified, it will be copied to `/etc/hostid` inside the container for
  inclusion in ZFSBootMenu images. If not, any `/etc/hostid` in the container
  will be removed. (Note: unless the `zfsbootmenu` dracut module is configured
  with `release_mode=1`, the module may still create an `/etc/hostid` with
  potentially arbitrary contents in output images.

  The environment variable or default can be overridded with the `-H` option.

- `$POOLCACHE` specifies the in-container path to a ZFS pool cache file. If
  this file is specified, it will be copied to `/etc/zfs/zpool.cache` inside
  the container for inclusion in ZFSBootMenu images. If not, any
  `/etc/zfs/zpool.cache` in the container will be removed.

  The environment variable or default can be overridded with the `-C` option.

- `$ZBMTAG` specifies any "commit-ish" label recognized by `git` as a pointer
  to a specific git commit. This can be a branch name (to grab the head of that
  branch), tag or commit hash. If `/zbm` in the container is not pre-populated,
  the container will fetch and unpack the named tag. By default, the value of
  `$ZBMTAG` will be taken from the contents of `/etc/zbm-commit-hash` if the
  container was built with the `ZBM_COMMIT_HASH` build argument; otherwise, the
  default is `master`. The tag is ignored if `/zbm` in the container is not
  empty.

  The environment variable or default can be overridded with the `-t` option.

An additional command-line argument, `-e`, allows the ZFSBootMenu configuration
to be modified with `yq-go eval` statements at container run time. Do not use
this unless you review the build script and understand, without documentation,
what will happen!

## Build Examples

To use the previously created `zbm` image to produce ZFSBootMenu files from the
default configuration using a local ZFSBootMenu repository `/sw/zfsbootmenu`,
simply run

```sh
podman run -v /sw/zfsbootmenu:/zbm zbm
```

After some console output, the container should terminate and the directory
`/sw/zfsbootmenu/releng/docker/build` should contain the UEFI bundle
`vmlinuz.EFI` as well as the components `vmlinuz-bootmenu` (a stock Void Linux
kernel) and corresponding ZFSBootMenu initramfs `initramfs-bootmenu.img`.

In the default configuration, the ZFSBootMenu images probably contain an
arbitrary `/etc/hostid` that likely does not agree with the corresponding file
on the host. To make sure that the hostid within the images remains consistent
with the build host, first copy the file from the host to the `releng/docker`
directory:

```sh
cp /etc/hostid /sw/zfsbootmenu/releng/docker/hostid
podman run -v /sw/zfsbootmenu:/zbm zbm
```

To create an image from the current `master` branch without having a local
repository, store the output images in `/boot/efi/EFI/zfsbootmenu` and include
the hostid of the current system, assuming a `zbm` builder container is tagged
locally:

```sh
mkdir -p /boot/efi/EFI/zfsbootmenu
podman run -v /boot/efi/EFI/zfsbootmenu:/output \
    -v /etc/hostid:/hostid:ro zbm -o /output -H /hostid
```

# Using Docker Compose

The file `docker-compose.yml` defines a Docker Compose service that will create
a ZFSBootMenu builder image and mount the parent repository (at path `../..`)
at `/zbm` in the build container. To use this service, simply run

```sh
docker-compose up
```

from this directory.

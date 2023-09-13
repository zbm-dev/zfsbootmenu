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
tree by default. From there, the path `releng/docker/build-init.sh` defines the
entrypoint for build containers. To run the `image-build.sh` script from
another directory, simply set the `ZBM_BUILDER` environment variable to the
location of the `build-init.sh` script to use.

For those without access to `buildah`, the `Dockerfile` will also create of a
ZFSBootMenu builder image. From this directory, simply run

    podman build --squash -t zbm .

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
the upstream git repository. Instead, the entrypoint `/build-init.sh` will
fetch a ZFSBootMenu archive when the container is instantiated (or allow a
local copy to be bind-mounted) and, as noted above, attempt to check out a
specific commit based on the contents of `/etc/zbm-commit-hash`.

# Running a ZFSBootMenu Builder Container

When running a container from the ZFSBootMenu builder image, it is generally
expected that some compatible volume (generally, a local directory) will be
bind-mounted as a volume at the path `/build` inside the container. The volume
may either be empty or contain a custom ZFSBootMenu configuration and will
contain build products (a UEFI bundle, separate kernel and initramfs
components, or both) in a `build` subdirectory.

The container entrypoint expects to run `generate-zbm` directly from a
ZFSBootMenu source repository that is available at `/zbm` within the container.
If the entrypoint finds `/zbm` nonexistent or devoid of files, it will fetch a
copy of the upstream source repository and unpack it where expected. (The tag,
commit or branch to fetch can be specified at runtime or a default will be
chosen as encoded in the container image.) Any pre-existing and non-empty
`/zbm` within the container must contain a copy of the source repository. This
is useful, *e.g.*, to bind-mount a local clone of the repository into the
container.

## Command-Line Arguments and Environment Variables

The build script accepts several command-line arguments or environment
variables that override its default behavior. Run the container with the `-h`
command-line argument to see a summary of build options and their default
options. The options are:

- `$BUILDROOT` specifies a default root for image builds. The build root is
  expected to hold configuration files and, optionally, an output directory,
  hostid and pool cache files. The value of `$BUILDROOT` is `/build` by
  default.

  The environment variable or default can be overridden with the `-b` option.

- `$ZBMOUTPUT` specifies an alternative output directory for ZFSBootMenu build
  products. The container *always* overrides configurations to store build
  products (UEFI bundles and kernel components, as configured) in a temporary
  directory; these products will be copied to `$ZBMOUTPUT` after successful
  image creation. The value of `$ZBMOUTPUT` is `${BUILDROOT}/build` by default.

  The environment variable or default can be overridden with the `-o` option.

- `$ZBMTAG` specifies any "commit-ish" label recognized by `git` as a pointer
  to a specific git commit. This can be a branch name (to grab the head of that
  branch), tag or commit hash. If `/zbm` in the container is not pre-populated,
  the container will fetch and unpack the named tag. By default, the value of
  `$ZBMTAG` will be taken from the contents of `/etc/zbm-commit-hash` if the
  container was built with the `ZBM_COMMIT_HASH` build argument; otherwise, the
  default is `master`. The tag is ignored if `/zbm` in the container is not
  empty.

  The environment variable or default can be overridden with the `-t` option.

A couple of additional arguments may only be set from the command line:

- `-e <statement>` provides a statement that will be evaluated via `yq-go eval`
  to modify the `generate-zbm` configuration file immediately before an image
  is built. This option may be specified more than once.

  > Do not use this unless you review the build script and understand, without
  > documentation, what will happen!

- `-p <package>` specifies a Void Linux package to install in the container
  before images are generated. This option may be specified more than once.

## ZFSBootMenu Configuration and Execution

After the ZFSBootMenu container entrypoint fetches (or identifies) a copy of
the ZFSBootMenu source repository, it "installs" the copy into the container by
symlinking key components of the source repository into the container
filesystem:

- If the source repository is sufficiently new, a symbolic link

      /usr/share/zfsbootmenu -> /zbm/zfsbootmenu

  will point to the core ZFSBootMenu library.

- For newer versions of ZFSBootMenu, the symbolic link

      /usr/lib/dracut/modules.d/90zfsbootmenu -> /zbm/dracut

  will point to the dracut module; for older versions, the link

      /usr/lib/dracut/modules.d/90zfsbootmenu -> /zbm/90zfsbootmenu

  will serve the same purpose.

- If the ZFSBootMenu repository contains a mkinitcpio module, a family of links

      /usr/lib/initcpio/hooks/* -> /zbm/initcpio/hooks/*
      /usr/lib/initcpio/install/* -> /zbm/initcpio/install/*

  for each file in `/zbm/initcpio/{hooks,install}` will be made to make
  `mkinitcpio` aware of the ZFSBootMenu module.

Configuration files are handled in a multi-pass approach that synthesizes a
composite configuration from increasingly specific sources. In the first pass,
generic upstream configurations are linked *if the source exists*:

    /etc/zfsbootmenu/config.yaml -> /zbm/etc/zfsbootmenu/config.yaml
    /etc/zfsbootmenu/mkinitcpio.conf -> /zbm/etc/zfsbootmenu/mkinitcpio.conf
    /etc/zfsbootmenu/dracut.conf.d/* -> /zbm/etc/zfsbootmenu/dracut.conf.d/*
    /etc/zfsbootmenu/mkinitcpio.conf.d/* -> /zbm/etc/zfsbootmenu/mkinitcpio.conf.d/*

Next, container-specific defaults are linked *if the source exists*:

    /etc/zfsbootmenu/config.yaml -> /zbm/etc/zbm-builder/config.yaml
    /etc/zfsbootmenu/mkinitcpio.conf -> /zbm/etc/zbm-builder/mkinitcpio.conf
    /etc/zfsbootmenu/dracut.conf.d/* -> /zbm/etc/zbm-builder/dracut.conf.d/*
    /etc/zfsbootmenu/mkinitcpio.conf.d/* -> /zbm/etc/zbm-builder/mkinitcpio.conf.d/*

Finally, build-specific configurations are linked *if the source exists*:

    /etc/zfsbootmenu/config.yaml -> ${BUILDROOT}/config.yaml
    /etc/zfsbootmenu/mkinitcpio.conf -> ${BUILDROOT}/mkinitcpio.conf
    /etc/zfsbootmenu/dracut.conf.d/* -> ${BUILDROOT}/dracut.conf.d/*
    /etc/zfsbootmenu/mkinitcpio.conf.d/* -> ${BUILDROOT}/mkinitcpio.conf.d/*

Conflicting links will *replace* any links made by earlier passes. This allows
each level of configurations to mask or augment earlier defaults.

> NOTE: `mkinitcpio` does not natively support configuration snippets in
> `/etc/zfsbootmenu/mkinitcpio.conf.d`. ZFSBootMenu includes a default
> `mkinitcpio.conf` that manually sources these snippets to emulate the
> standard configuration behavior of dracut.

In addition, the hostid file is linked if it exists:

    /etc/hostid -> ${BUILDROOT}/hostid

## Container Customization

When launched, the container entrypoint will run any executable "hook" files it
finds in either of the directories `${BUILDROOT}/rc.pre.d` or
`${BUILDROOT}/rc.d`. These hooks provide a means to "terraform" the build
container before producing a ZFSBootMenu image. For example, hooks might be
used to

- Modify the `FONT` variable defined in `/etc/rc.conf`, which will be parsed by
  `mkinitcpio` to set a default console font in ZFSBootMenu images.

- Create additional links to directories in `$BUILDROOT`, such as

      /etc/initcpio -> ${BUILDROOT}/initcpio

  to provide additional `mkinitcpio` modules or

      /etc/dropbear -> ${BUILDROOT}/dropbear

  to provide host keys and configuration for the `dropbear` `mkinitcpio`
  module.

The `rc.pre.d` hooks will execute after installing any requested packages in
the container, but before confirming the existence of (or populating) a
ZFSBootMenu repository at `/zbm`. These early hooks provide a means for,
*e.g.*, overriding the standard process for fetching ZFSBootMenu source
archives.

The `rc.d` hooks will execute after completion of the ZFSBootMenu setup process
described in the preceding section, but before the standard configuration is
modified according to any `-e` arguments provided to the container and
`generate-zbm` is execute. These late hooks provide a last-minute opportunity
to customize ZFSBootMenu configuration before creating an image.

## Build Examples

To use the previously created `zbm` image to produce ZFSBootMenu files from the
default configuration, simply run

    podman run -v .:/build zbm

After some console output, the container should terminate and the directory
`./build` should contain the UEFI bundle `vmlinuz.EFI` as well as the
components `vmlinuz-bootmenu` (a stock Void Linux kernel) and corresponding
ZFSBootMenu initramfs `initramfs-bootmenu.img`.

To provide the hostid and pool cache files to the build container and run from
the `/etc/zfsbootmenu/build` directory, copy the desired files and run the
container with the appropriate volume mount:

    cp /etc/hostid /etc/zfsbootmenu/build
    podman run -v /etc/zfsbootmenu/build:/build zbm

To create an image from a local repository available at `/sw/zfsbootmenu` and
again use a build root of `/etc/zfsbootmenu/build`, run

    podman run -v /etc/zfsbootmenu/build:/build -v /sw/zfsbootmenu:/zbm:ro zbm

Because the build container does not modify the repository found in `/zbm`, it
is possible to mount that volume read-only (as indicated by the `:ro` suffix)
without consequence.

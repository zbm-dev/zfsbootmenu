ZFSBootMenu Build Containers
============================

.. toctree::
  :hidden:

  container-example

.. contents:: Contents
  :depth: 2
  :local:
  :backlinks: none

Introduction
------------

Official ZFSBootMenu release assets are built within OCI containers based on the
`zbm-builder image <https://github.com/zbm-dev/zfsbootmenu/pkgs/container/zbm-builder>`_. The image is built atop
`Void Linux <https://voidlinux.org/>`_ and provides a predictable environment without the need to install ZFSBootMenu or
its dependencies on the host system. While ZFSBootMenu is officially packaged for Void Linux and is guaranteed to work
well with the tools provided therein, the experience is not always as smooth for users of other distributions. System
packages for ZFSBootMenu or its requirements may be missing entirely. Tooling may be outdated and missing features that
ZFSBootMenu uses to provide an enhanced user experience. (Where possible, ZFSBootMenu will test for features and work
around their absence.) The ``zbm-builder`` container image provides a means to work around the limitations of particular
distributions and provides all users with first-class ZFSBootMenu support.

The ``zbm-builder.sh`` script provides a front-end for integrating custom ZFSBootMenu configurations into the build
container without the complexity of directly controlling the container runtime.

Users wishing to build custom ZFSBootMenu images should be familiar with the core concepts of ZFSBootMenu as outlined in
the :zbm:`project README <README.md>`. For those interested, the :zbm:`container README <releng/docker/README.md>`
provides more details on the operation of the ZFSBootMenu build container. However, the ``zbm-builder.sh``
:zbm:`build helper <zbm-builder.sh>` provides a front-end for integrating custom ZFSBootMenu configurations into the
build container and abstracts away many of the complex details discussed in that document.

Dependencies
------------

To build ZFSBootMenu images from a build container, either `podman <https://podman.io>`_ or
`docker <https://www.docker.com>`_ is required. The development team prefers ``podman``, but ``docker`` may generally be
substituted without consequence.

If a custom build container is desired, `buildah <https://buildah.io>`_ and ``podman`` are generally required. A
:zbm:`Dockerfile <releng/docker/Dockerfile>` is provided for convenience, but feature parity with the ``buildah``
script is not guaranteed. The :zbm:`container README <releng/docker/README.md>` provides more information about the
process of creating a custom build image.

Podman
~~~~~~

Install ``podman`` and ``buildah`` (if desired) using the package manager in your distribution:

* On Void, ``xbps-install podman buildah``
* On Arch or its derivatives, ``pacman -S podman buildah``
* On Debian or its derivatives, ``apt-get install podman buildah``

It is possible to configure ``podman`` for rootless container deployment. Consult the
`tutorial <https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md>`_ for details.

Docker
~~~~~~

Install ``docker`` using the package manager in your distribution:

- On Void, ``xbps-install docker``
- On Arch or its derivatives, ``pacman -S docker``
- On Debian or its derivatives, ``apt-get install docker``

Non-root users that should be permitted to work with Docker images and containers should belong to the ``docker``
groups. For example::

  usermod -a -G docker zbmuser

will add ``zbmuser`` to the ``docker`` group on systems that provide the ``usermod`` program.

The Build Container and Its Helper
----------------------------------

The ``zbm-builder`` container is based on a Void Linux image that uses an LTS kernel and a relatively recent version of
ZFS. When run, the container entrypoint will:

1. Fetch a specified or default version of the ZFSBootMenu source repository (or use a local copy that is bind-mounted
   into the container);
2. Perform an "installation" of this repository into the container instance to ensure that ZFSBootMenu is usable within;
3. Optionally run some scripts to customize the container instance;
4. Merge default and build-specific ZFSBootMenu configurations; and
5. Produce a ZFSBootMenu image.

To facilitate interaction with the host, the container should be run with a build directory (along with an output
directory, if it is not already a child of the build directory) bind-mounted into the container.


.. note::

  Advanced users may wish to build images from a local copy of the ZFSBootMenu source tree. To make this possible,
  either fetch and unpack a source tarball or clone the git repository locally. The local repository should be
  bind-mounted to the ``/zbm`` directory within the container.

The ``zbm-builder.sh`` helper script requires nothing more than functional installations of ``bash`` and one of
``podman`` or ``docker``. Simply download a copy of the script to a convenient directory. The helper coordinates volume
mounts necessary to read configurations from and write output to the host and ensures that the system's hostid file is
passed through. The script also supports a simple configuration file that allows options to be recorded for repeated
use.

Building a ZFSBootMenu Image
----------------------------

To build a default image, invoke ``zbm-builder.sh`` with no arguments. For example, from the directory that contains the
script, run ``./zbm-builder.sh`` to produce a default kernel/initramfs pair in the ``./build`` subdirectory.

The default behavior of ``zbm-builder.sh`` will:

1. Pull the default builder image, ``ghcr.io/zbm-dev/zbm-builder:latest``.
2. If ``./hostid`` does not exist, copy ``/etc/hostid`` (if it exists) to ``./hostid``.
3. Spawn an ephemeral container from the builder image and run its build process:

  1. Bind-mount the working directory into the container to expose local configurations to the builder
  2. If ``./config.yaml`` exists, inform the builder to use that custom configuration instead of the default
  3. Run the internal build script to produce output in the ``./build`` subdirectory

.. note::

  Building on hosts with SELinux enabled may require that volumes mounted by the build container be properly labeled.
  This can be accomplished by specifying the argument ``-M z`` to ``zbm-builder.sh``. This will persistently relabel the
  build directory and, if specified, the ZFSBootMenu source directory. As an alternative to conf, it may be possible to
  disable SELinux entirely by invoking ``zbm-builder.sh`` with the argument ``-O --security-opt=label=disable``.

  When Dracut is used to build an image under the constraints of SELinux, ``zbm-builder.sh`` should additionally be
  invoked with the argument ``-O --env=DRACUT_NO_XATTR=1`` to prevent Dracut from setting extended attributes on
  temporary files it creates within the container. Without this option, Dracut may try, but fail, to set the
  ``security.selinux`` attribute on files.

Custom ZFSBootMenu Hooks
~~~~~~~~~~~~~~~~~~~~~~~~

ZFSBootMenu supports :ref:`custom hooks <zbm-dracut-options>` in three stages:

1. ``early_setup`` hooks run after the ``zfs`` kernel driver has been loaded, but before ZFSBootMenu attempts to import
   any pools.
2. ``setup`` hooks run after pools are imported, right before ZFSBootMenu will either boot a default environment or
   present a menu.
3. ``teardown`` hooks run immediately before ZFSBootMenu will ``kexec`` the kernel for the selected environment.

When ``zbm-builder.sh`` runs, it will identify custom hooks as executable files in the respective subdirectories of its
build directory:

1. ``hooks.early_setup.d``
2. ``hooks.setup.d``
3. ``hooks.teardown.d``

For each hook directory that contains at least one executable file, ``zbm-builder.sh`` will write custom configuration
snippets for ``dracut`` and ``mkinitcpio`` that will include these files in the output images.

Fully Customizing Images
~~~~~~~~~~~~~~~~~~~~~~~~

The entrypoint for the ZFSBootMenu implements a
:zbm:`tiered configuration approach <releng/docker/README.md#zfsbootmenu-configuration-and-execution>`
that allows default configurations to be augmented or replaced with local configurations in the build directory. A
custom ``config.yaml`` may be provided in the working directory to override the default ZFSBootMenu configuration;
configuration snippets for ``dracut`` or ``mkinitcpio`` can be placed in the ``dracut.conf.d`` and ``mkinitcpio.conf.d``
subdirectories, respectively. For ``mkinitcpio`` configurations, a complete ``mkinitcpio.conf`` can be placed in the
working directory to override the standard configuration.

.. note::

  The ``mkinitcpio`` configuration prepared by ``zbm-builder.sh`` may include custom snippets installed in a
  ``mkinitcpio.d`` subdirectory of the build directory. The
  :zbm:`default mkinitcpio configuration <etc/zbm-builder/mkinitcpio.conf>` includes a loop to source these snippets.
  Should you prefer to overide the default ``mkinitcpio.conf`` in your build, any files in the ``mkinitcpio.d``
  subdirectory will need to be sourced within your custom configuration. In general, it is better to leave the default
  ``mkinitcpio.conf`` and store all custom configurations in the ``mkinitcpio.d`` subdirectory.

The build container runs its build script from the working directory on the host. In general, relative paths in custom
configuration files are generally acceptable and refer to locations relative to the build directory. If absolute paths
are preferred or required for some configurations, note that the build directory will be mounted as ``/build`` in the
container.

The internal build script **always** overrides the output paths for ZFSBootMenu components and UEFI executables to
ensure that the images will reside in a specified output directory (or, by default, a ``build`` subdirectory of build
directory) upon completion. Relative paths are primarily useful for specifying local ``dracut`` or ``mkinitcpio``
configuration paths.

More advanced users may wish to alter the build process itself. Some control over the build process is exposed through
command-line options that are described in the output of ``zbm-builder.sh -h``.

Before adjusting these command-line options, seek a thorough understanding of the
:zbm:`image build process <releng/docker/README.md>` and the command sequence of ``zbm-builder.sh`` itself.

..
  vim: softtabstop=2 shiftwidth=2 textwidth=120

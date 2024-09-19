.. image:: _static/logo-header.svg
   :alt: ZFSBootMenu logo
   :align: center
   :class: dark-light

.. raw:: html

  <br>
  <div class="dl-links">
    <a class="dl-button" href="https://get.zfsbootmenu.org/efi"><i class="fa-solid fa-download"></i> x86_64 EFI Image</a>
    <a class="dl-button" href="https://get.zfsbootmenu.org/efi/recovery"><i class="fa-solid fa-download"></i> x86_64 Recovery Image</a>
    <a class="dl-button" href="https://github.com/zbm-dev/zfsbootmenu"><i class="fa-brands fa-github"></i> View on GitHub</a>
  </div>
  <br>
  <div class="dl-links">
    <a href="https://github.com/zbm-dev/zfsbootmenu/actions/workflows/build.yml">
      <img alt="Build check" src="https://github.com/zbm-dev/zfsbootmenu/actions/workflows/build.yml/badge.svg?branch=master">
    </a>
    <a href="https://repology.org/project/zfsbootmenu/versions">
      <img alt="latest packaged version(s)" src="https://repology.org/badge/latest-versions/zfsbootmenu.svg">
    </a>
  </div>
  <br>

.. toctree::
  :maxdepth: 1
  :titlesonly:
  :hidden:

  CHANGELOG

.. toctree::
  :caption: Manual Pages
  :maxdepth: 3
  :titlesonly:
  :includehidden:
  :hidden:

  man/zfsbootmenu.7
  man/generate-zbm.8
  man/zbm-kcl.8

.. toctree::
  :caption: General Information
  :maxdepth: 3
  :titlesonly:
  :includehidden:
  :hidden:

  general/binary-releases
  general/bootenvs-and-you
  general/container-building
  general/mkinitcpio
  general/native-encryption
  general/portable
  general/remote-access
  general/tailscale
  general/uefi-booting
  general/grub-migration
  general/mdraid-esp

.. toctree::
  :caption: Installation Guides
  :maxdepth: 3
  :titlesonly:
  :includehidden:
  :hidden:

  guides/void-linux
  guides/alpine
  guides/chimera
  guides/debian
  guides/fedora
  guides/opensuse
  guides/ubuntu
  guides/third-party

.. toctree::
  :caption: Runtime Help
  :maxdepth: 3
  :titlesonly:
  :hidden:

  online/main-screen
  online/snapshot-management
  online/diff-viewer
  online/kernel-management
  online/zpool-health
  online/recovery-shell

..
  This should be kept reasonably synchronized with README.md in the repository root.

ZFSBootMenu is a bootloader that provides a powerful and flexible discovery, manipulation and booting of Linux on ZFS.
Originally inspired by the FreeBSD bootloader, ZFSBootMenu leverages the features of modern OpenZFS to allow users to
choose among multiple "boot environments" (which may represent different versions of a Linux distribution, earlier
snapshots of a common root, or entirely different distributions), manipulate snapshots in a pre-boot environment and,
for the adventurous user, even bootstrap a system installation via ``zfs recv``.

In essence, ZFSBootMenu is a small, self-contained Linux system that knows how to find other Linux kernels and initramfs
images within ZFS filesystems. When a suitable kernel and initramfs are identified (either through an automatic process
or direct user selection), ZFSBootMenu launches that kernel using the ``kexec`` command.

.. image:: _static/screenshot.png
  :alt: ZFSBootMenu screenshot
  :align: center

.. raw:: html

  <br>

Overview
========

.. contents::
  :depth: 2
  :local:
  :backlinks: none

In broad strokes, ZFSBootMenu works as follows:

* Via direct EFI booting, an EFI boot manager like ``rEFInd``, a BIOS bootloader like ``syslinux``, or some other means,
  boot a ZFSBootMenu image (as either a self-contained UEFI application or a dedicated Linux kernel and initramfs).
* Find all healthy ZFS pools and import them (or, at the user's option, find and import only a specific pool).
* If appropriate, select a preferred boot environment:

  * If the ZFSBootMenu command line specifies a pool preference, and that pool has been imported, prefer the filesystem
    indicated by its ``bootfs`` property (if defined).
  * If the ZFSBootMenu command line specifies no pool preference or the preferred pool is not found, prefer the
    filesystem indicated by the ``bootfs`` property (if defined) on the first-found pool.
  * If a suitable ``bootfs`` has been identified, start an interruptable countdown (by default, 10 seconds) to
    automatically boot that environment.
  * If no ``bootfs`` value can be identified or the automatic countdown was interrupted, search all imported pools for
    filesystems that set ``mountpoint=/`` and contain Linux kernels and initramfs images in their ``/boot``
    subdirectories. Present a list of matching environments for user selection via ``fzf``.

* Mount the filesystem representing the selected boot environment and find either the highest versioned kernel or a
  specifically selected kernel version in its ``/boot`` directory.
* Using ``kexec``, load the selected kernel and its initramfs image into memory, setting the kernel command line with
  the contents of the ``org.zfsbootmenu:commandline`` property for that filesystem.
* Unmount all ZFS filesystems.
* Boot the final kernel and initramfs.

At this point, the system will be booting into your usual OS-managed kernel and initramfs, along with any arguments
needed to correctly boot your system.

Whenever ZFSBootMenu encounters natively encrypted ZFS filesystems that it intends to scan for boot environments, it
will prompt the user to enter a passphrase as necessary.

Distribution Agnostic
---------------------

ZFSBootMenu is capable of booting just about any Linux distribution. Distributions that are known to boot without
requiring any special configuration include:

* Void
* Chimera
* Alpine
* openSUSE (Leap, Tumbleweed)
* Gentoo
* Fedora
* Debian and its descendants (Ubuntu, Linux Mint, Devuan, etc.)
* Arch

Red Hat and its descendants (RHEL, CentOS, etc.) are expected to work as well but have never been tested.

ZFSBootMenu provides several configuration options that can be used to fine-tune the boot process for nonstandard
configurations.

Easily Deployed and Extensively Configurable
--------------------------------------------

Each release includes pre-generated boot images, based on Void Linux, that should work for the majority of users. These
images are available for ``x86_64`` UEFI and legacy BIOS systems in the form of an EFI executable or a kernel and
initramfs. Users of other platforms or that require custom configurations can build local images, running the
ZFSBootMenu image generator either in a host installation or in the controlled environment of an OCI (Docker) container.

Modern UEFI platforms provide a wide range of :doc:`options for launching ZFSBootmenu </general/uefi-booting>`.
For legacy BIOS systems, ``syslinux`` is a convenient choice. A
:doc:`syslinux guide for Void Linux </guides/void-linux/syslinux-mbr>` describes the ``syslinux``
installation and configuration process in the context of a broader Void Linux installation.

Local Installation
~~~~~~~~~~~~~~~~~~

The ZFSBootMenu repository includes a :zbm:`Makefile <Makefile>` with targets to install the
:doc:`generate-zbm </man/generate-zbm.8>` builder, all necessary components, manual pages and some convenient helpers. A
local ZFSBootMenu installation requires some additional software that may be available as packages in your distribution
or may need to be manually installed. The following components are required or recommended for inclusion in the
bootloader image:

  * `fzf <https://github.com/junegunn/fzf>`_
  * `kexec-tools <https://github.com/horms/kexec-tools>`_
  * `mbuffer <http://www.maier-komor.de/mbuffer.html>`_ (recommended, but not required)

In addition, ``generate-zbm`` requires a few Perl modules:

  * `perl Sort::Versions <https://metacpan.org/pod/Sort::Versions>`_
  * `perl YAML::PP <https://metacpan.org/pod/YAML::PP>`_
  * `perl boolean <https://metacpan.org/pod/boolean>`_

If you will create unified EFI executables (which bundles the kernel, initramfs and command line), you will also need a
an EFI stub loader, which is typically included with
`systemd-boot <https://www.freedesktop.org/wiki/Software/systemd/systemd-boot/>`_ or
`gummiboot <https://pkgs.alpinelinux.org/package/edge/main/x86/gummiboot>`_.

Most or all of these software components may be available as packages in your distribution.

Locally created ZFSBootMenu images use your regular system kernel, ZFS drivers and user-space utilities. The
ZFSBootMenu image is constructed using standard Linux initramfs generators. ZFSBootMenu is known to work and is
explicitly supported with:

* `dracut <https://github.com/dracutdevs/dracut>`_
* `mkinitcpio <https://github.com/archlinux/mkinitcpio>`_

.. note:

  ZFSBootMenu does *not* replace your regular initramfs image. In fact, it is possible to use any of the supported
  initramfs generators to produce a ZFSBootMenu image even on Linux distributions which use an entirely different
  program to produce their own initramfs images (*e.g.*, ``initramfs-tools`` on Debian or Ubuntu).

Building a custom image is known to work in the following configurations:

* With ``mkinitcpio`` or ``dracut`` on Void (the ``zfsbootmenu`` package will make sure all prerequisites are available)
* With ``mkinitcpio`` or ``dracut`` on Arch
* With ``dracut`` on Debian or Ubuntu (installed as ``dracut-core`` to avoid replacing the system ``initramfs-tools`` setup)

Configuration of the ZFSBootMenu build process is accomplished via a :doc:`YAML configuration file</man/generate-zbm.5>`
for ``generate-zbm``.

Building in a Container
~~~~~~~~~~~~~~~~~~~~~~~

The official ZFSBootMenu release images are built in a standard Void Linux OCI container that provides a predictable
environment that is known to be supported with ZFSBootMenu. The container entrypoint provides full access to all of the
configurability of ZFSBootMenu, and a helper script simplifies the process or running the container and managing the
images that it produces. The :doc:`ZFSBootMenu container guide </general/container-building>` provides a detailed
description of the containerized build process as well as a straightforward example of local image management using the
helper script.

ZFS Boot Environments
---------------------

The concept of a "boot environment" is very loosely defined in ZFSBootMenu. Fundamentally, ZFSBootMenu treats any
filesystem that appears to be an operating system root and contains an identifiable Linux kernel and initramfs as a boot
environment. A :doc:`primer </general/bootenvs-and-you>` provides more details about the identification process.

Command-Line Arguments
~~~~~~~~~~~~~~~~~~~~~~

When booting a particular enviornment, ZFSBootMenu reads the ``org.zfsbootmenu:commandline``
:ref:`property <zfs-properties>` for that filesystem to discover kernel command-line arguments that should be passed to
the kernel it will boot.

.. note::

  Do not set a ``root=`` option (or any similar indicator of the root filesystem) in this property; ZFSBootMenu will add
  an appropriate ``root=`` argument when it boots the environment and will actively suppress any conflicting option.

Because ZFS properties are inherited by default, it is possible to set the ``org.zfsbootmenu:commandline`` property on a
common parent to apply the same KCL arguments to multiple environments. Setting the property locally on individual boot
environments will override the common defaults.

As a special accommodation, the substitution keyword ``%{parent}`` in the KCL property will be recursively expanded to
whatever the value of ``org.zfsbootmenu:commandline`` would be on the parent dataset. This allows, for example, mixing
options common to multiple environments with those specific to each::

  zfs set org.zfsbootmenu:commandline=""zfs.zfs_arc_max=8589934592"" zroot/ROOT
  zfs set org.zfsbootmenu:commandline="%{parent} loglevel=4" zroot/ROOT/void.2019.11.01
  zfs set org.zfsbootmenu:commandline="loglevel=7 %{parent}" zroot/ROOT/void.2019.10.04

will cause ZFSBootMenu to interpret the KCL for ``zroot/ROOT/void.2019.11.01`` as::

  zfs.zfs_arc_max=8589934592 loglevel=4

while the KCL for ``zroot/ROOT/void.2019.10.04`` would be::

  loglevel=7 zfs.zfs_arc_max=8589934592

To simplify the manipulation of command-line parameters for boot environments, the :doc:`zbm-kcl </man/zbm-kcl.8>` helper
facilitates live review and edits.

Run-time Configuration of ZFSBootMenu
-------------------------------------

ZFSBootMenu may be configured via a combination of :ref:`command-line parameters <cli-parameters>` and
:ref:`ZFS properties <zfs-properties>` that are described in detail in the :doc:`zfsbootmenu(7) </man/zfsbootmenu.7>`
manual page. For users of pre-built UEFI executables, the :doc:`zbm-kcl </man/zbm-kcl.8>` helper script provides a
convenient way to modify the embedded ZFSBootMenu command line without requiring the creation of a custom image.

Signature Verification and Prebuilt EFI Executables
---------------------------------------------------

All release assets, including EFI executables and kernel/initramfs pairs, are signed with
`signify <https://flak.tedunangst.com/post/signify>`_, which provides a simple method for verifying that the contents of
the file are as this project intended. Once you've installed ``signify`` (that's left as an exercise, although Void
Linux provides the ``signify`` package for this purpose), just download the desired assets from the
`ZFSBootMenu release page <https://github.com/zbm-dev/zfsbootmenu/releases>`_, download the file ``sha256.sig``
alongside it, and run::

  signify -C -x sha256.sig

You will need the public key used to sign ZFSBootMenu executables. The key is available at
:zbm:`releng/keys/zfsbootmenu.pub`. Install this file as ``/etc/signify/zfsbootmenu.pub`` if you like; this key can be
used for all subsequent verifications. Otherwise, look at the ``-p`` command-line option for ``signify`` to provide a
path to the key.

The signature file ``sha256.sig`` also includes a signature for the source tarball corresponding to the release. If this
file is not present alongside the EFI bundle and the signature file, ``signify`` will complain about its signature. This
error message is OK to ignore; alternatively, tell ``signify`` to verify only the EFI bundle, or download the source
tarball alongside the other files.

The signify key ``zfsbootmenu.pub`` may itself be verified; alongside the public key is the GPG signature
:zbm:`releng/keys/zfsbootmenu.pub.gpg`, produced with a `personal key from @ahesford <https://github.com/ahesford.gpg>`_,
one of the members of the ZFSBootMenu project. This personal key is also available on public key servers. To verify the
``signify`` key, download the key ``zfsbootmenu.pub`` and its signature file ``zfsbootmenu.pub.gpg``, then run::

  gpg --recv-key 0x312485BE75E3D7AC
  gpg --verify zfsbootmenu.pub.gpg

.. note::

  On some distributions, ``gpg`` may instead by ``gpg2``.

..
  vim: softtabstop=2 shiftwidth=2 textwidth=120

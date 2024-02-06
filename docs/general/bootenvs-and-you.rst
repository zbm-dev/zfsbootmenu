Boot Environments and You: A Primer
===================================

ZFSBootMenu adapts to a wide range of system configurations by making as few assumptions about filesystem layout as
possible. When looking for Linux kernels to boot, the *only* requirements are that:

1. At least one ZFS pool be importable,
2. At least one ZFS filesystem on any importable pool have *either* the properties

   * ``mountpoint=/`` and **not** ``org.zfsbootmenu:active=off``, or
   * ``mountpoint=legacy`` and ``org.zfsbootmenu:active=on``

   For filesystems with ``mountpoint=/``, the property ``org.zfsbootmenu:active`` provides a means to opt **out** of
   scanning this filesystem for kernels. For filesystems with ``mountpoint=legacy``, ``org.zfsbootmenu:active`` provides
   a means to opt **in** to scanning this filesystem for kernels. Filesystems that do not satisfy these conditions are
   *never* touched by ZFSBootMenu.

3. At least one of the scanned ZFS filesystems contains a ``/boot`` subdirectory that contains at least one paired
   kernel and initramfs.

ZFSBootMenu will present a list of all ZFS filesystems that satisfy these constraints. Additionally, if any filesystem
provides more than one paired kernel and initramfs, it is possible to choose which kernel will be loaded should that
filesystem be selected for booting. (It is, of course, possible to automate the selection of a filesystem and kernel so
that ZFSBootMenu can boot a system without user intervention.)

Finding Kernels
---------------

Although it may be possible to compile a kernel with built-in ZFS support that would be capable of booting from a ZFS
root without an initramfs, this is not standard practice and would require considerable expertise. Consequently,
ZFSBootMenu requires that a kernel be matched with an initramfs image before it will attempt to boot the kernel.
ZFSBootMenu tries hard to identify matched pairs of kernels and initramfs images as installed by a wide range of Linux
distributions. As noted above, kernel and initramfs pairs are required to reside in a ``/boot`` subdirectory of ZFS
filesystem scanned by ZFSBootMenu. The kernel must begin with one of the following prefixes:

* vmlinuz
* vmlinux
* linux
* linuz
* kernel

After the prefix, the name of a kernel may be optionally followed by a hyphen (``-``) and an arbitrary string, which
ZFSBootMenu considers a *version* identifier.

ZFSBootMenu attempts to match one of several possible initramfs names for each kernel it identifies. Broadly, an
initramfs is paired with a kernel when its name matches one of four forms:

* ``initramfs-${label}${extension}``
* ``initramfs${extension}-${label}``
* ``initrd-${label}${extension}``
* ``initrd${extension}-${label}``

The value of ``${extension}`` may be empty or the text ``.img`` and may additionally be followed by one of several
common compression suffixes: ``gz``, ``bz2``, ``xz``, ``lzma``, ``lz4``, ``lzo``, or ``zstd``. The value of
``${label}`` is either:

* The full name of the kernel file with path components removed, *e.g.*, ``vmlinuz-5.15.9_1`` or ``linux-lts``; or
* The version part of a kernel file (if the kernel contains a version part):

  * For ``vmlinuz-5.15.9_1``, this is ``5.15.9_1``;
  * For ``linux-lts``, this is ``lts``.

ZFSBootMenu prefers the more specific label (the full kernel name) when it exists.

Boot Environments
-----------------

Internally, ZFSBootMenu does not understand the concept of a boot environment. When it finds a suitable kernel and
initramfs pair, it will load them and invoke ``kexec`` to jump into the chosen kernel. In fact, ZFSBootMenu doesn't even
require that a "root" filesystem be the real root that a kernel and initramfs will mount. It would be possible, for
example, to mount a ZFS filesystem at ``/kernels`` and install kernels and matching initramfs images to the
``/kernels/boot`` subdirectory. As long as the ``/kernels`` filesystem has a ``mountpoint`` property (along with
``org.zfsbootmenu:active`` if needed), ZFSBootMenu will identify the kernels even if the filesystem at ``/kernels``
contains nothing besides the ``boot`` subdirectory.

Although ZFSBootMenu ensures maximum flexibility by imposing minimal assumptions on filesystem layout, not all layouts
are equally sensible. For straightforward maintenance and administration, it is recommended that each Linux operating
system that you wish to boot be stored as a self-contained boot environment. Conceptually, the ZFSBootMenu team
recommends that a *boot environment* consist of a **single** ZFS filesystem that contains all of the *coupled* system
state for that environment. Coupled system state embodies the executables, configuration and other files that are
critical to proper system operation and must generally be kept consistent at all times. In most systems, coupled system
state tends to be maintained by a package manager. The package manager might install programs in ``/usr/bin``,
configuration in ``/etc`` and other files throughout the filesystem. The package manager itself probably maintains a
database of installed packages somewhere in ``/var``.

ZFSBootMenu is certainly capable of booting an environment that mounts separate filesystems at ``/`` and other paths
like ``/etc``, ``/usr`` or ``/var``. ZFSBootMenu never needs to understand these details because either the initramfs or
root filesystem will assume responsibility for mounting all filesystems it needs. However, a key benefit of boot
environments is *atomicity*. In general, it is bad to allow the contents of ``/usr`` to become inconsistent with the
package manager database on ``/var``. Configuration files in ``/etc`` can often be tied to specific versions of
software, so they should be kept consistent as well. When these directories live on different filesystems, ensuring
consistency becomes much more challenging.

For example, suppose that a software update has gone wrong and a program has been overwritten by a corrupt or buggy
version. With ZFS snapshots, ``zfs rollback`` is sufficient to restore functionality. However, when ``/usr`` and
``/var`` reside on different filesystems, both must be rolled back to the same point in time. When the filesystems are
on different snapshot schedules (or there is some delay between snapshotting one after the other), deciding which
snapshots represent consistent state may not be a trivial task.

To some extent, this could be remedied with a recursive snapshot scheme that provides uniform nomenclature for
consistent snapshots across multiple filesystems. However, ZFSBootMenu strives to provide simple management and recovery
interfaces for all boot environments on a disk, and

1. Providing a convenient interface for rollback of a boot environment becomes substantially harder if ZFSBootMenu has
   to identify snapshots across multiple filesystems that might compose an environment,

2. Even identifying which filesystems should be considered part of an environment is not always a trivial task, and

3. The problem gets significantly more complex when a system holds multiple boot environments that might each have
   multiple sub-mounts.

Keeping the entire operating system contents on a single filesystem avoids these issues entirely. For the purposes of
rolling back snapshots or cloning one boot environment to another, ZFSBootMenu expects that the environment consists of
exactly one filesystem, so that a snapshot of the filesystem always presents a consistent view of system state, and
rollbacks or clones behave as expected without the need for manual correlation. If you wish to maintain more complicated
setups, you can always manually manage snapshot rollbacks or clone operations from the recovery shell that ZFSBootMenu
provides.

Note that "coupled system state" does not include "user data" that should generally survive things like snapshot
rollbacks. Recovering from a bad system update is generally not expected to discard user email or recent database
transactions. For this reason, directories like ``/home``, ``/var/mail`` and others that hold important data *not*
managed by the system **should** reside on separate filesystems.

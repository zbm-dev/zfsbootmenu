Recovery Shell
==============

Common Commands
---------------

**zfsbootmenu**

  Launch the interactive boot environment menu.

**zfs-chroot** *filesystem*

  Enter a chroot of the specified boot environment. The boot environment is mounted *read/write* if the zpool is imported *read/write*.

**zkexec** *filesystem kernel initramfs*

  Directly *kexec* a kernel and initramfs from a boot environment, allowing any kernel and initramfs to be loaded into memory and immediately booted.

**set_rw_pool** *pool*

  Export, then re-import the pool *read/write*.

**set_ro_pool** *pool*

  Export, then re-import the pool *read-only*.

**mount_zfs** *zfs filesystem*

  Mount the filesystem at a unique location and print the mount point.

**help**

  View the online help system.

**logs**

  View warning/error/debug logs.

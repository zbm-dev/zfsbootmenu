Recovery Shell
==============

Common Commands
---------------

**zfsbootmenu** | **zbm**

  Launch the interactive boot environment menu.

**zfs-chroot** *dataset*

  Enter a chroot of the specified boot environment. The boot environment is mounted *read/write* if the zpool is imported *read/write*.

**zkexec** *dataset kernel initramfs*

  Directly *kexec* a kernel and initramfs from a boot environment, allowing any kernel and initramfs to be loaded into memory and immediately booted.

**zsnapshots** *dataset*

  Access the snapshot browser for a dataset, allowing cloning and rollback operations to be initiated.

**zreport**

  List ZFS module, pool and dataset details for bug reports.

**zbmcmdline**

  Show the aggregated commandline from */etc/cmdline*, */etc/cmdline.d/* and */proc/cmdline*.

**set_rw_pool** *pool*

  Export, then re-import the pool *read/write*.

**set_ro_pool** *pool*

  Export, then re-import the pool *read-only*.

**mount_zfs** *dataset*

  Mount the filesystem at a unique location and print the mount point.

**mount_esp** *device*

  Mount an EFI System Partition at a unique location and print the mount point.

**mount_efivarfs** *mode*

  Mount or remount *efivarfs* as read-write or read-only.

**help**

  View the online help system.

**logs**

  View warning/error/debug logs.

**shutdown|poweroff**

  Shutdown the system using a SysRq magic invocation.

**reboot**

  Reboot the system using a SysRq magic invocation.

**firmware-setup**

  Reboot the system into the UEFI Firmware Setup interface (if available).

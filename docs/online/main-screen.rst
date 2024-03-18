Main Screen
===========

Keyboard Shortcuts
------------------

*[ENTER]* **boot**

  Boot the selected boot environment, with the listed kernel and kernel command line visible at the top of the screen.

*[MOD+K]* **kernels**

  Access a list of kernels available in the boot environment.

*[MOD+S]* **snapshots**

  Access a list of snapshots of the selected boot environment. New boot environments can be created here.

*[MOD+D]* **set bootfs**

  Set the selected boot environment as the default for the pool.

  The operation will fail gracefully if the pool can not be set *read/write*.

*[MOD+E]* **edit kcl**

  Temporarily edit the kernel command line that will be used to boot the chosen kernel in the selected boot environment. This change does not persist across reboots.

*[MOD+T]* **revert kcl**

  Revert the temporary kernel command line set via *[MOD+E]*.

*[MOD+P]* **pool status**

  View the health and status of each imported pool.

*[MOD+R]* **recovery shell**

  Execute a Bash shell with minimal tooling, enabling system maintenance.

*[MOD+J]* **jump into chroot**

  Enter a chroot of the selected boot environment. The boot environment is mounted *read/write* if the zpool is imported *read/write*.

*[MOD+W]* **import read/write**

  If possible, the pool behind the selected boot environment is exported and then re-imported in *read/write* mode.

  This is not possible if any of the following conditions are met:

  * The version of ZFS in ZFSBootMenu has detected unsupported pool features, due to an upgraded pool.
  * The system has an active **resume**, indicating that the pool is currently in use.

  Upon successful re-import in *read/write* mode, each of the boot environments on this pool will be highlighted in *red* at the top of the screen.

*[MOD+O]* **sort order**

  Cycle the sorting key through the following list:

  * **name** Use the filesystem or snapshot name
  * **creation** Use the filesystem or snapshot creation time
  * **used** Use the filesystem or snapshot size

  The default sort key is *name*.

*[MOD+L]* **view logs**

  View logs, as indicated by *[!]*. The indicator will be yellow for warning conditions and red for errors.

*[MOD+X]* **power menu**

  Show menu with options to shutdown, reboot, or reboot to UEFI firmware setup (if available).

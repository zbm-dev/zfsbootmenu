===========
ZFSBootMenu
===========

SYNOPSIS
========

ZFSBootMenu behavior is controlled through ZFS filesystem properties and command-line options provided to the ZFSBootMenu kernel.

.. _cli-parameters:

Command-Line Parameters
=======================

These options are set on the kernel command line when booting the initramfs or UEFI bundle. Default options were chosen to allow general systems to boot without setting any values.

**spl_hostid=<hostid>**

  When creating an initramfs or UEFI bundle, the */etc/hostid* from the system is copied into the target. If this image will be used on another system with a different hostid, replace **<hostid>** with the desired hostid, as an eight-digit hexadecimal number, to override the value contained within the image.

**zbm.prefer**

  ZFSBootMenu will attempt to import as many pools as possible to identify boot environments and will, by default, look for the *bootfs* property on the first imported pool (sorted alphabetically) to select the default boot environment. This option controls this behavior.

  **zbm.prefer=<pool>**

    The simplest form attempts to import **<pool>** before any other pool. The *bootfs* value from this pool will control the default boot environment.

  **zbm.prefer=<pool>!**

    If a literal *!* has been appended to the pool name, ZFSBootMenu will insist on successfully importing the named pool before attempting to import any others.

  **zbm.prefer=<pool>!!**

    If a literal *!!* has been appended to the pool name, ZFSBootMenu will insist on successfully importing the named pool and no others.


**zbm.retry_delay=<time>**

  This option determines the interval between repeated attempts of required steps. When **<time>** is unspecified or is anything other than a positive integer, a default value of 5 seconds will be used. Should ZFSBootMenu fail to successfully import any pool, it will repeat import attempts indefinitely until at least one pool can be imported or the user chooses to drop to a recovery shell. Additionally, should any required devices be configured via **zbm.wait_for**, device checks will repeat on this interval.

**zbm.import_policy**

  This option controls how the pool import process should take place.

  **zbm.import_policy=hostid**

    Set this option to allow run-time reconfiguration of the SPL hostid. If a pool is preferred via **zbm.prefer** and the pool can not be imported with a preconfigured hostid, the system will attempt to adopt the hostid of the system that last imported the pool. If a preferred pool is not set and no pools can be imported using a preconfigured hostid, the system will adopt the hostid of the first otherwise-importable pool. After adopting a detected hostid, ZFSBootMenu will subsequently attempt to import as many pools as possible. This is the default import policy.

  **zbm.import_policy=strict**

    Set this option to only import pools that match the SPL hostid configured in ZFSBootMenu. If none can be imported, an emergency shell will be invoked. The *strict* policy is consistent with the behavior of earlier versions of ZFSBootMenu.

  **zbm.import_policy=force**

    Set this option to attempt to force pool imports. When set, this invokes *zpool import -f* in place of the regular *zpool import* command, which will attempt to import a pool that's potentially in use on another system. Use this option with caution!

**zbm.set_hostid**

  Setting this option will cause ZFSBootMenu to set the *spl.spl_hostid* command-line parameter for the selected boot environment to the hostid used to import its pool. The SPL kernel module will use this value as the hostid of the booted environment regardless of the contents of */etc/hostid*. As a special case, if the hostid to be set is zero, ZFSBootMenu will instead set *spl_hostid=00000000*, which should be used by dracut-based initramfs images to write an all-zero */etc/hostid* in the initramfs prior to importing the boot pool. This option is on by default.

  .. note::

    Setting *spl.spl_hostid* to a non-zero value on the kernel commandline will make the ZFS kernel modules **ignore** any value set in */etc/hostid*. To restore standard ZFS behavior on a running system, execute

    .. code-block::

      echo 0 > /sys/module/spl/parameters/spl_hostid

**zbm.sort_key**

  This option accepts a ZFS property name by which the boot environment and snapshot lists will be sorted.

  **zbm.sort_key=name**

    Sort the lists by *name*. This is the default sorting method.

  **zbm.sort_key=creation**

    Sort the lists by *creation* date.

  **zbm.sort_key=used**

    Sort the lists by size *used*.

**zbm.timeout**

  This option accepts numeric values that control whether and when the boot-environment menu should be displayed.

  **zbm.timeout=0** | **zbm.skip**

    When possible, bypass the menu and immediately boot a configured *bootfs* pool property.

  **zbm.timeout=-1** | **zbm.show**

    Rather than present a countdown timer for automatic selection, immediately display the boot-environment menu.

  **zbm.timeout=<positive integer>**

    Display a countdown timer for the specified number of seconds before booting the configured *bootfs* boot environment.

**zbm.hookroot=<hookspec>**

  Tell ZFSBootMenu to attempt to read any early-setup, setup or teardown hooks from the path specified by *hookspec* in addition to any included directly in the image.

  The *hookspec* parameter takes the form

  .. code-block::

    device//path

  where *device* is either a regular device node (e.g., */dev/sda*) or other partition identifier recognized by :manpage:`mount(8)` (e.g., *LABEL=<label>* o *UUID=<uuid>*). The *path* component following *//* represents the location of a directory with respect to the root of the filesystem on *device*. For example, if a partition with a UUID of *DEAD-BEEF* is mounted at */boot/efi* on a running system and the hook root should refer to the path

  .. code-block::

    /boot/efi/EFI/zfsbootmenu/hooks,

  the corresponding hook specification should be

  .. code-block::

    zbm.hookroot=UUID=DEAD-BEEF//EFI/zfsbootmenu/hooks

  on the ZFSBootMenu command line. Note that any kernel modules necessary to mount the specified filesystem must be present in the ZFSBootMenu image. (For example, mounting a FAT32 filesystem may require that *vfat.ko*, *fat.ko*, *nls_cp437.ko* and *nls_iso8859_1.ko* be added to the image.)

  Within the hook root, create subdirectories *early-setup.d*, *setup.d*, *load-key.d*, *boot-sel.d* or *teardown.d* to hold hooks for the respective stages of hook execution. ZFSBootMenu will mount the device named by the hook specification, look for the individual hook directories, and copy any files found therein into its own memory-backed root filesystem. The copy is not recursive and further subdirectorie are ignored. Note that, because ZFSBootMenu copies these scripts into its standard hook paths at each boot, it is possible to "mask" a script explicitly included in the ZFSBootMenu image by including an external hook script with the same name in the appropriate directory.

**zbm.kcl_override="boot environment KCL"**

  Override the kernel command line passed in to all boot environments. Double quotes must be used to encapsulate the value of this argument. Arguments that need spaces should be enclosed with single quotes. *root* is always removed. *spl_hostid* and *spl.spl_hostid* are removed if the default-enabled option *zbm.set_hostid* is set.

  .. code-block::

    zbm.kcl_override="some alternate set='of arguments'"

**zbm.skip_hooks=<hooklist>**

  Skip execution of any early-setup, setup, load-key, boot-selection or teardown hooks with file names matching any entry in the comma-separated list *hooklist*. Only base names of hooks (*i.e.*, with any other path component removed) are matched against the *hooklist*.

  **NOTE**: The *hooklist* argument **MUST NOT** contain spaces and **MUST NOT** be enclosed in quotes.

**zbm.autosize**

  Enable automatic font resizing of the kernel console to normalize the apparent resolution for both low resolution and high resolution displays. This option is enabled by default.

**zbm.wait_for=device,device,...**

  Ensure that one or more devices are present before starting the pool import process. Devices may be specified as full paths to device nodes (*e.g.*, **/dev/sda** or **/dev/disk/by-id/wwn-0x500a07510ee65912**) or, for convenience, as a typed indicator of the form **TYPE=VALUE**, which will be expanded internally as
  
    **/dev/disk/by-TYPE/VALUE**

  The use of full device paths other than descendants of **/dev/disk/** is fragile and should be avoided. The delay interval between device checks can be controlled by **zbm.retry_delay**.

Deprecated Parameters
---------------------

**timeout**

  Deprecated; use **zbm.timeout**.

**root=zfsbootmenu:POOL=<pool>**

  Deprecated; use **zbm.prefer**.

**force_import=1**

  Deprecated; use **zbm.import_policy=force**.

**zbm.force_import=1**

  Deprecated; use **zbm.import_policy=force**.

**zbm.import_delay**

  Deprecated; use **zbm.retry_delay**

.. _zfs-properties:

ZFS Pool Properties
===================

The following properties can be set at the pool level to control boot behavior.

**bootfs**

  A dataset that will be considered the default boot environment if the pool is the first to be imported by ZFSBootMenu.

.. note::

  This must be set for automatic booting to function. When no **bootfs** property is detected, ZFSBootMenu will always display a selection menu.

ZFS Dataset Properties
======================

The following properties can be set at any level of the boot-environment hierarchy to control boot behavior.

**org.zfsbootmenu:kernel**

  An identifier used to select which kernel to boot among all kernels found in the */boot* directory of the selected boot environment. This can be a partial kernel name (e.g., *5.4*) or a full filename (e.g., *vmlinuz-5.7.11_1*).

  If the identifier does not match any kernels, the latest kernel will be chosen as a fallback.

**org.zfsbootmenu:commandline**

  A list of command-line arguments passed to the kernel selected by ZFSBootMenu for final boot. The special keyword *%{parent}* will be recursively expanded to the value of **org.zfsbootmenu:commandline** at the parent of the boot environment. Thus, for example,

  .. code-block::

    zfs set org.zfsbootmenu:commandline="zfs.zfs_arc_max=8589934592" zroot
    zfs set org.zfsbootmenu:commandline="%{parent} elevator=noop" zroot/ROOT
    zfs set org.zfsbootmenu:commandline="loglevel=7 %{parent}" zroot/ROOT/be

  will cause ZFSBootMenu to interpret the kernel command-line for *zroot/ROOT/be* as

  .. code-block::

    loglevel=7 zfs.zfs_arc_max=8589934592 elevator=noop

  Never set the *root=* argument; ZFSBootMenu always sets this option based on the selected boot environment.

**org.zfsbootmenu:active**

  This controls whether boot environments appear in or are hidden from ZFSBootMenu.

  **off**

    For boot environments with *mountpoint=/*, set **org.zfsbootmenu:active=off** to **HIDE** the environment.

  **on**

    For boot environments with *mountpoint=legacy*, set **org.zfsbootmenu:active=on** to **SHOW** the environment.

By default, ZFSBootMenu only shows boot environments with the property *mountpoint=/*.

**org.zfsbootmenu:rootprefix**

  This specifies the prefix added to the ZFS filesystem provided as the root filesystem on the kernel command line. For example, the command-line argument *root=zfs:zroot/ROOT/void* has root prefix *root=zfs:*.

  The default prefix is *root=zfs:* for most boot environments. Environments that appear to be Arch Linux will use *zfs=* by default, while those that appear to be Gentoo or Alpine will use a default of *root=ZFS=*. The root prefix is generally determined by the initramfs generator, and the default is selected to match the expectation of the preferred initramfs generator on each distribution.

  Set this property to override the value determined from inspecting the boot environment.

**org.zfsbootmenu:keysource=<filesystem>**

  If specified, this provides the name of the ZFS filesystem from which keys for a particular boot environment will be sourced.

  Normally, when ZFSBootMenu attempts to load encryption keys for a boot environment, it will attempt to look for a key file at the path specified by the *keylocation* property on the *encryptionroot* for that boot environment. If that file does not exist, and *keyformat=passphrase* is set for the *encryptionroot* (or *keylocation=prompt*), ZFSBootMenu will prompt for a passphrase to unlock the boot environment. These passphrases entered are not cached by default.

  When **org.zfsbootmenu:keysource** is a mountable ZFS filesystem, before prompting for a passphrase when *keylocation* is not set to *prompt*, ZFSBootMenu will attempt to mount **<filesystem>** (unlocking that, if necessary) and search for the key file within **<filesystem>**. When **<filesystem>** specifies a *mountpoint* property that is not *none* or *legacy*, the specified mount point will be stripped (if possible) from the beginning of any *keylocation* property to attempt to identify a key at the point where it would normally be mounted. If no file exists at the stripped path (or the *mountpoint* specifies *none* or *legacy*), keys will be sought at the full path of *keylocation* relative to **<filesystem>**. If a key is found at either location, it will be copied to the initramfs. The copy in the initramfs will be used to decrypt the original boot environment. Copied keys are retained until ZFSBootMenu boots an environment, so a single password prompt can be sufficient to unlock several pools with the same *keysource* or prevent prompts from reappearing when the pool must be exported and reimported (for example, to alter boot parameters from within ZFSBootMenu).

.. _zbm-dracut-options:
.. _zbm-mkinitcpio-options:

Options for dracut and mkinitcpio
=================================

In addition to standard configuration options for the dracut or mkinitcpio initramfs image builders, the ZFSBootMenu module for each of these builders supports additional options to customize ZFSBootMenu images.

**zfsbootmenu_module_root=<path>**

  Set this variable to override the default **<path>** where the ZFSBootMenu module expects to find core components that must be installed in the created image. When unspecified, a default of */usr/share/zfsbootmenu* is assumed.

**zfsbootmenu_hook_root=<path>**

  Set this variable to override the default **<path>** where the ZFSBootMenu module expects to find optional user hooks that will be installed in the created image. When unspecified, a default of */etc/zfsbootmenu/hooks* is assumed.
  
**zfsbootmenu_skip_gcc_s=yes**

  The ZFSBootMenu module attempts to detect and install a copy of the library **libgcc_s.so** in its initramfs image on glibc systems. Because several executables may have latent dependencies on this library via a **dlopen** call in glibc itself, a failure to detect and install the library will cause initramfs generation to fail. If the host system has no dependencies on **libgcc_s.so**, set **zfsbootmenu_skip_gcc_s=yes** to avoid this failure. Alternatively, if **libgcc_s.so** is present in an undetected location, set this option and configure dracut or mkinitcpio to explicitly install the library.

**zfsbootmenu_miser=yes** (mkinitcpio only)

  By default, **mkinitcpio** uses busybox to populate initramfs images. However, the *zfsbootmenu* hook will install system versions of several utilities that it requires to operate. On most systems, these versions will be provided by util-linux rather than busybox. To prefer busybox for these utilities when possible, set **zfsbootmenu_miser=yes**. Synonyms for *yes* are *1*, *y* or *on*, without regard to letter case.


Deprecated Options
------------------

**zfsbootmenu_early_setup=<executable-list>**

  Deprecated; place early-setup hooks in the directory *${zfsbootmenu_hook_root}/early-setup.d*.

**zfsbootmenu_setup=<executable-list>**

  Deprecated; place setup hooks in the directory *${zfsbootmenu_hook_root}/setup.d*.

**zfsbootmenu_teardown=<executable-list>**

  Deprecated; place teardown hooks in the directory *${zfsbootmenu_hook_root}/teardown.d*.

.. _user-hooks:

User Hooks
==========

At various points during operation, ZFSBootMenu will execute optional hooks that allow critical operations to be supplemented with custom behavior. System hooks are provided in the directory *${zfsbootmenu_module_root}/hooks* and are automatically installed in all ZFSBootMenu images. User hooks may be provided in the directory *${zfsbootmenu_hook_root}*.

Hooks should be marked executable and placed in a subdirectory of *${zfsbootmenu_hook_root}* named according to the point at which the hooks are executed:

**early-setup.d**

  Early-setup hooks will be installed from the directory *${zfsbootmenu_hook_root}/early-setup.d*. These hooks will be executed after the SPL and ZFS kernel modules are loaded and a hostid is configured in */etc/hostid*, but before any zpools have been imported.

**setup.d**

  Setup hooks will be installed from the directory *${zfsbootmenu_hook_root}/setup.d*. These hooks will be executed right before the ZFSBootMenu menu will be presented; ZFS pools will generally have been imported and the default boot environment will be available in the *BOOTFS* environment variable. Hooks will not be run if the countdown timer expires (or was set to zero) and the default boot environment is automatically selected. **Note:** The hooks may be run multiple times if the menu is invoked multiple times, e.g., by dropping to an emergency shell and then returning to the menu. If a script should only run once, the script is responsible for keeping track of this.

**load-key.d**

  Load-key hooks will be installed from the directory *${zfsbootmenu_hook_root}/load-key.d*. These hooks will be executed immediately before ZFSBootMenu attempts to unlock an encrypted and locked filesystem. Two environment variables will be exported to describe the filesystem that must be unlocked:

  **ZBM_LOCKED_FS**

    The ZFS filesystem that must be unlocked.

  **ZBM_ENCRYPTION_ROOT**

    The encryption root of the locked filesystem.

  ZFSBootMenu will abandon its attempt to unlock the filesystem and indicate success if the filesystem is not locked after execution of any load-key hook. If the filesystem remains locked after hook execution, ZFSBootMenu will continue with its standard unlocking attempt.

**boot-sel.d**
**teardown.d**

  Boot-selection hooks will be installed from the directory *${zfsbootmenu_hook_root}/boot-sel.d*. These hooks will be executed after a user has selected a boot environment, but before ZFSBootMenu attempts to load and boot the kernel.

  Teardown hooks will be installed from the directory *${zfsbootmenu_hook_root}/teardown.d*. These hooks will be executed after the kernel for a selected environment has been loaded and is launching via **kexec** is imminent. Some hardware initialized by the ZFSBootMenu kernel may not be properly reinitialized when a boot environment is launched; teardown hooks may be useful to unbind drivers from problematic hardware or remove associated kernel modules.

  Boot-selection and teardown hooks each have access to three environment variables that describe the boot environment that is about to be launched:

  **ZBM_SELECTED_BE**

    The ZFS filesystem containing the boot environment that is about to be launched.

  **ZBM_SELECTED_KERNEL**

    The path to the kernel that will be booted, relative to the root of **ZBM_SELECTED_BE**.

  **ZBM_SELECTED_INITRAMFS**

    The path to the initramfs corresponding to the selected kernel, again relative to the root of **ZBM_SELECTED_BE**.

  Additionally, boot-selection hooks will have access to a fourth environment variable:

  **ZBM_SELECTED_MOUNTPOINT**

    The path where the selected boot environment is currently mounted, which is the root relative to which ZFSBootMenu will attempt to load the selected kernel and initramfs.

  Teardown hooks should never assume that the filesystem named in **ZBM_SELECTED_BE** is currently mounted. In addition, no teardown hook should assume that the ZFSBootMenu environment is in a consistent operating state. ZFSBootMenu may have exported some or all pools prior to executing teardown hooks.

  In general, it is not possible to cleanly abort a boot attempt from boot-selection or teardown hooks. However, a boot-selection or teardown hook may take control of the boot attempt by implementing its own **kexec** load and execution without returning to ZFSBootMenu. This may be useful, for example, to allow ZFSBootMenu to select a boot environment and then restructure the boot process to launch a Xen kernel with the selected environment configured as dom0.


SEE ALSO
========

:doc:`generate-zbm(5) </man/generate-zbm.5>` :doc:`generate-zbm(8) </man/generate-zbm.8>` :manpage:`dracut.conf(5)` :manpage:`mkinitcpio.conf(5)`

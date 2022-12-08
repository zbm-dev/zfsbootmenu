===========
ZFSBootMenu
===========

SYNOPSIS
========

ZFSBootMenu behavior is controlled through ZFS filesystem properties and command-line options provided to the ZFSBootMenu kernel.

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


**zbm.import_delay=<time>**

  Should ZFSBootMenu fail to successfully import any pool, it will repeat import attempts indefinitely until at least one pool can be imported or the user chooses to drop to a recovery shell. Each subsequent attempt will proceed after a delay of **<time>** seconds. When **<time>** is unspecified or is anything other than a positive integer, a default value of 5 seconds will be used.

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

      echo 0 > /sys/module/spl/paramters/spl_hostid

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

  Within the hook root, create subdirectories *early-setup.d*, *setup.d* or *teardown.d* to hold hooks for the respective stages of hook execution (early-setup, setup and teardown). ZFSBootMenu will mount the device named by the hook specification, look for the individual hook directories, and copy any files found therein into its own memory-backed root filesystem. The copy is not recursive and further subdirectorie are ignored. Note that, because ZFSBootMenu copies these scripts into its standard hook paths at each boot, it is possible to "mask" a script explicitly included in the ZFSBootMenu image by including an external hook script with the same name in the appropriate directory.

Deprecated Command-Line Parameters
==================================

**timeout**

  Deprecated; use **zbm.timeout**.

**root=zfsbootmenu:POOL=<pool>**

  Deprecated; use **zbm.prefer**.

**force_import=1**

  Deprecated; use **zbm.import_policy=force**.

**zbm.force_import=1**

  Deprecated; use **zbm.import_policy=force**.

ZFS Properties
==============

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

Options for dracut
==================

In addition to standard dracut configuration options, the ZFSBootMenu dracut module supports addtional options to customize boot behavior.

**zfsbootmenu_early_setup=<executable-list>**

  An optional variable specifying a space-separated list of paths to setup hooks that will be installed in the ZFSBootMenu initramfs. Any path in the list **<executable-list>** that exists and is executable will be installed.

  Any installed early hooks are run after SPL and ZFS kernel modules are loaded and a hostid is configured in */etc/hostid*, but before any zpools have been imported.

**zfsbootmenu_setup=<executable-list>**

  An optional variable specifying a space-separated list of paths to setup hooks that will be installed in the ZFSBootMenu initramfs. Any path in the list **<executable-list>** that exists and is executable will be installed.

  Any installed hooks are run right before the ZFSBootMenu menu will be presented; ZFS pools will generally have been imported and the default boot environment will be available in the *BOOTFS* environment variable. Hooks will not be run if the countdown timer expires (or was set to zero) and the default boot environment is automatically selected. **Note:** The hooks may be run multiple times if the menu is invoked multiple times, e.g., by dropping to an emergency shell and then returning to the menu. If a script should only run once, the script is responsible for keeping track of this.

**zfsbootmenu_teardown=<executable-list>**

  An optional variable specifying a space-separated list of paths to teardown hooks that will be installed in the ZFSBootMenu initramfs. Any path in the list **<executable-list>** that exists and is executable will be installed.

  Some hardware initialized by the kernel used to boot ZFSBootMenu may not be properly reinitialized when a boot environment is launched. Any teardown hooks installed into the ZFSBootMenu initramfs will be run immediately before **kexec** is invoked to jump into the selected kernel. This script can be used, for example, to unbind drivers from hardware or remove kernel modules.

  Teardown hooks have access to three environment variables that describe the boot environment that is about to be launched:

  **ZBM_SELECTED_BE**

    The ZFS filesystem containing the boot environment that is about to be launched.

  **ZBM_SELECTED_KERNEL**

    The path to the kernel that will be booted, relative to the root of **ZBM_SELECTED_BE**.

  **ZBM_SELECTED_INITRAMFS**

    The path to the initramfs corresponding to the selected kernel, again relative to the root of **ZBM_SELECTED_BE**.

  The hook *must not* assume that the filesystem **ZBM_SELECTED_BE** is currently mounted or that the pool on which it resides is currently imported. However, a teardown hook has the freedom to import a pool (preferably read-only) and mount the boot environment to inject additional processing before boot. To abort a pending boot, invoking

  .. code-block::

    kexec --unload

  should be sufficient to return to the main menu. Likewise, the hook may construct and execute its own *kexec* command to alter boot-time parameters. This may be useful, for example, to allow ZFSBootMenu to select a boot environment and then restructure the boot process to launch a Xen kernel with the selected environment configured as dom0.

.. _zbm-mkinitcpio-options:

Options for mkinitcpio
======================

The **dracut** options specified above may also be specified in a mkinitcpio configuration file when **generate-zbm** is configured to create images using **mkinitcpio**. However, whereas the **<executable-list>** values in the dracut configuration should be specified as a single, space-separated string; in the mkinitcpio configuration, each **<executable-list>** value must be specified as a Bash array like the standard mkinitcpio arguments.

The following additional arguments may be provided in the mkinitcpio configuration file to further control the creation of ZFSBootMenu images:

**zfsbootmenu_module_root=<path>**

  Set this variable to override the default **<path>** where the mkinitcpio hook looks for the components of ZFSBootMenu that must be installed in the created image.

**zfsbootmenu_miser=yes**

  By default, **mkinitcpio** uses busybox to populate initramfs images. However, the *zfsbootmenu* hook will install system versions of several utilities that it requires to operate. On most systems, these versions will be provided by util-linux rather than busybox. To prefer busybox for these utilities when possible, set **zfsbootmenu_miser=yes**. Synonyms for *yes* are *1*, *y* or *on*, without regard to letter case.

SEE ALSO
========

:doc:`generate-zbm(5) </man/generate-zbm.5>` :doc:`generate-zbm(8) </man/generate-zbm.8>` :manpage:`dracut.conf(5)` :manpage:`mkinitcpio.conf(5)`
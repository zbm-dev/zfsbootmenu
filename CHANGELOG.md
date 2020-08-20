# ZFSBootMenu v1.4.1 (2020-08-19)

ZFSBootMenu 1.4.1 is a minor update, updating the provided Makefile for packagers.


# ZFSBootMenu v1.4 (2020-08-19)

ZFSBootMenu 1.4 includes significant internal changes and some user-visible functional changes in the `generate-zbm` script.

## Fixes
* Correct an issue that required two attempts to set default boot environments.
* Internal improvements to `generate-zbm` to improve consistency and facilitate future development.
* Management of versioned image retention should now be more consistent with expectation. Versioned ZBM images now increment a revision number when existing images with the same version already exist, and the retention policy preserves a configurable number of revisions for the current version alongside the latest revision of each of the same number of prior versions.
* Improved error handling should make failures in `generate-zbm` easier to understand.

## New features
* Provide man pages (generate-zbm.5, generate-zbm.8 and zfsbootmenu.7) to document the creation and use of ZFSBootMenu images.
* Move from an INI configuration format to YAML, which should provide more flexibility for future enhancements.
* Provide a `--migrate` command-line option to convert existing INI configurations to the new format.
* Add configuration options to change default behavior for `--kernel`, `--kver` and `--prefix` to make `generate-zbm` easier to incorporate on non-Void systems.
* Add a configuration option to change the default behavior for `--version` to allow customized output versioning of images.
* Support string interpolation of `%current` or `%{current}` tags in `--kver` and `--version` values.
* Add a `--cmdline` command-line option to override the configured `CommandLine` value without editing the configuration file.

## Significant commits in this release
* 0979051 - Add documentation for generate-zbm, its config and initramfs options (Zach Dykstra, et al.)
* ee1d9d8 - Unmask import_args in functions calling import_pool (Zach Dykstra)
* 3b2b2f0 - Add explicit --migrate option to generate-zbm (Andrew J. Hesford)
* 3cd3a8e - Improve error handling and automatic config conversion (Andrew J. Hesford)
* 80e0c30 - Switch syslinux entry to heredoc, fix syslinux.cfg file copy (Zach Dykstra)
* 6351226 - Move to YAML configuration, improve version handling (Andrew J. Hesford, Zach Dykstra)
* 5fdb872 - Add configuration options for kernel, version and prefix (Andrew J. Hesford)
* 79295ec - Add an optional parameter to safeCopy: (Zach Dykstra)
* 8aa133f - Clean up control flow in generate-zbm (Andrew J. Hesford)


# ZFSBootMenu v1.4rc1 (2020-08-11)

Except for the addition of man pages and the fix in commit ee1d9d8, the new features and fixes in this release are fully described in the final v1.4 release notes.


# ZFSBootMenu v1.3.1 (2020-07-14)

This release fixes an issue found minutes after v1.3 was tagged and released - such is life. After timing out on the countdown menu, the screen is now cleared before displaying a prompt for the pool password.

# ZFSBootMenu v1.3 (2020-07-14)

This release features several fixes and new features.

## Fixes
* When creating a boot image, `generate-zbm` will fail if the EFI System Partition (`BootMountPoint` in the configuration) is not and cannot be mounted.
* When `generate-zbm` creates backup kernels, initramfs images or UEFI bundles, timestamps of the original files will be preserved when possible, which may help boot loaders like rEFInd properly order the images.
* Some display issues in the boot menu have been fixed.

## New features
The following new features should allow ZFSBootMenu to work with distributions such as Arch or Ubuntu:
*  The Dracut module now searches for a much broader range of kernel/initramfs pairs in boot environments, including unversioned kernels with names like `linux` or `vmlinuz`.
* `generate-zbm` now has a `--kver` argument that can specify a version number when one cannot be correctly determined from the name of a kernel file, allowing creation of ZFSBootMenu images on systems like Arch that do not encode version information in kernel names.
* When starting a boot environment, the `root=` command-line argument is now set with a prefix (*e.g.*, the `zfs:` part of `root=zfs:pool/ROOT/void`) that is chosen based on distribution ID in `/etc/os-release` or `/usr/lib/os-release`, if available; the default selection can be overridden by setting the `org.zfsbootmenu:rootprefix` property.

In addition:
* In the ZFSBootMenu snapshot browser, an option to view a `zfs diff` between the live boot environment and a selected snapshot allow convenient review of the changes since the snapshot was taken.
* ZFSBootMenu now attempts to detect an active suspend-to-disk image and prevent any operations on ZFS pools that could lead to corruption on resume.
* The currently selected boot environment and kernel are displayed throughout submenus.
* In addition to identifying boot environments by the property `mountpoint=/`, ZFSBootMenu will also identify boot environments with the properties `mountpoint=legacy` and `org.zfsbootmenu:active=on`.
* Boot environments with `mountpoint=/` can be hidden from ZFSBootMenu by setting the property `org.zfsbootmenu:active=off`.

## Significant commits in this release
* 7122be9 - Use mountpoint to check for ESP (Zach Dykstra)
* 315e326 - Check return of mount operation (Zach Dykstra)
* 8e434b1 - Allow root prefix to be customized for other distributions (Andrew J. Hesford)
* fcaba86 - Support unversioned kernel naming in generate-zbm (Andrew J. Hesford)
* 294a84d - Broaden search for kernels and initramfs images (Andrew J. Hesford)
* 2263dbe - Handle kernels with multi-part versions (Zach Dykstra)
* 95f65a6 - Initial support for org.zfsbootmenu:active visibility (Andrew J. Hesford)
* 69c3d63 - Draw the preview header on kernel, snapshot and diff screens (Zach Dykstra)
* 83b2cbb - Initial support for resume guard (Andrew J. Hesford)
* 6828550 - Initial snapshot diff browser (Zach Dykstra)
* 4c0a968 - Report source size when cloning/duplicating a snapshot (Zach Dykstra)


# ZFSBootMenu v1.3rc2 (2020-07-09)

This release contains all of the fixes and new features in v1.3rc1, as well as some fixes to command-line generation that should allow ZFSBootMenu to properly boot Arch Linux systems.


# ZFSBootMenu v1.3rc1 (2020-07-07)

The new features and fixes in this release are fully described in the final v1.3 release notes.


# ZFSBootMenu v1.2 (2020-06-22)

This release features substantial code and idea contributions from @ahesford . Thank you for all of your help writing features, debugging code and improving documentation.

### Snapshot overhaul

Previously, snapshots could be cloned to a boot environment with a pre-generated, and often long, BE name. Substantial quality of life improvements were made here, including:

* Add the ability to do a full zfs send | zfs recv clone from a local snapshot. This lets you establish a new boot environment that is not dependent on any other environments or snapshots.
* Add the ability to clone and promote a snapshot, or simply clone it.
* When cloning a snapshot, local ZFS properties of the parent filesystem are now transferred to the clone.
* For all snapshot operations, you can now directly enter a boot environment name. This name is checked for character validity, and to confirm that it is not already taken.

### Always up-to-date menu system

Any time you transition from one menu to another (Snapshots, Kernels, recovery shell), the list of boot environments and kernels is completely regenerated. This helps remove potential disconnects between the state of your pool and boot environments and the ZFSBootMenu interface.

### UEFI bundle improvements

If you create unversioned UEFI bundles for static boot entries, `generate-zbm` will now create a `-backup` file for you on upgrade. This will allow you a recovery option if the active UEFI bundle has a problem.

### Protect against missing kernel modules

When creating a new initramfs, the `zfsbootmenu` Dracut module needs to install a number of ZFS-related kernel modules. Previously, the modules were installed through a Dracut helper function that did not verify if the copy succeeded. This process has been reworked to ensure that all of the required kernel modules are installed in the initramfs, or the creation of the image is marked as a failure. If it is marked as a failure, existing/current images are not deleted or otherwise replaced.

### Set default kernel

Much like setting a default boot environment, you can now set a default kernel for a specific boot environment. You no longer need to manually set a kernel version in your booted OS, you can simply do it from the menu!

### Shellcheck

On commit, the shell scripts that power the boot menu and Dracut setup are run through a validator to check for common errors and pitfalls. This can help reduce some classes of bugs.


# ZFSBootMenu v1.1 (2020-06-11)

This release includes a number of small fixes and improvements.

# Fixes
* Correctly handle exiting the recovery shell, fixing an infinite loop. A reboot is no longer required to recover from the recovery shell. Thanks, @ahesford.
* Check that the EFI stub file is present on disk at the specified location. If the file is missing and an EFI bundle is requested, exit with an error.
* Minor documentation fixes.

# Features
* Handle console fonts defined on the kernel command line. This is useful for systems with a 4k display. You should now be able to read the screen without a magnifying glass. Thanks to @ahesford for the significant time spent on tracking this down.
* Instead of calling `objcopy` directly, `dracut` is now used to generate a bundled EFI file. This means that the bundled EFI file can now be signed by Secure Boot keys! Thanks to @ericonr for this feature - and learning a bit of Perl to do it!

No configuration file changes are needed to use this release. Enjoy!


# ZFSBootMenu v1.0 (2020-05-15)

We're jumping straight up to v1.0!

# Small changes
* Set the kernel log level to 0 when in the menu system, then restore it to the original value on boot
* Reverse sort the kernel list, so the most recent is always first
* Add an initial chroot helper script, `zfs-chroot` for the recovery shell. It can be invoked as `zfs-chroot pool/ROOT/BE`.
* Set the default config path in `generate-zbm` to `/etc/zfsbootmenu/conf.d`
* Allow the EFI stub file to be defined in config.ini
* Optionally read the kernel command line from `/etc/default/zfsbootmenu`

# Large changes
* Clean up or whitelist all issues in `zfsbootmenu-lib.sh`, `zfsbootmenu-preview.sh` and `zfsbootmenu.sh` noted by shellcheck.
* Support entering a custom kernel command line via `alt-c` on the main menu. The input line is pre-filled with the command line that would have been used on the next boot, for that environment. This command line is NOT persisted between reboots, it's simply here to let you recover an unbootable system.
* Add support for reading the kernel commandline from the ZFS property `org.zfsbootmenu:commandline`.  This property is now considered the default/primary source of truth for the kernel command line - it takes precedence over `/etc/default/zfsbootmenu` and `/etc/default/grub`.

A big thank you to @ahesford for his code contributions and testing leading up to this release!


# ZFSBootMenu v1.0rc2 (2020-05-12)

This release contains all of the fixes and features from 1.0rc1, as well as the following:

* Add support for reading the kernel commandline from the ZFS property `org.zfsbootmenu:commandline`. This property takes precedence over `/etc/default/grub` and `/etc/default/zfsbootmenu`
* Clean up or whitelist all issues in `zfsbootmenu-lib.sh`, `zfsbootmenu-preview.sh` and `zfsbootmenu.sh` noted by shellcheck.

A big thank you to @ahesford for his code contributions and testing leading up to this release candidate. It is very much appreciated!


# ZFSBootMenu 1.0rc1 (2020-05-11)

This release has been a long time coming. In no particular order, it contains the following:

* Set the kernel log level to 0 when in the menu system, then restore it to the original value on boot
* Reverse sort the kernel list, so the most recent is always first
* Add an initial chroot helper script for the recovery shell
* Set the default config path in `generate-zbm` to `/etc/zfsbootmenu/conf.d`
* Allow the EFI stub file to be defined in config.ini
* Support entering a custom kernel command line via `alt-c` on the main menu. The input line is pre-filled with the command line that would have been used on the next boot, for that environment. This command line is NOT persisted between reboots, it's simply here to let you recover an unbootable system.


# ZFSBootMenu 0.8.1 (2020-01-19)

This release adds a few improvements to generate-zbm.

* When finding kernels in /boot to use as the base for zfsbootmenu, the list is properly sorted so something like 5.4.11 is now a higher version than 5.3.18.
* Output files now have `_1` appended to them (both kernel and initramfs) to workaround a gotcha with Petitboots' syslinux.cfg parser ignoring files ending in `.0`.
* If the bootloader partition is defined in config.ini, generate-zbm will now mount it and unmount it for you. If it's already mounted, it's left alone.
* Syslinux mode now builds off of [Components] mode, instead of adding yet another code path for generating the initramfs. This makes syslinux mode simply a syslinux.cfg renderer.


# ZFSBootMenu 0.8.0 (2020-01-12)

This release adds a preview function to the primary menu screen. Two lines are shown at the top of the display.

Line 1: Selected boot environment (if it's the bootfs) - and the default kernel
Line 2: The discovered kernel arguments for the kernel in that boot environment

Additional features added in include:

* Set bootfs for a pool via `alt+d` on the main menu screen
* Ability to clone the same snapshot up to 1000 times. After cloning a snapshot, it can be set as the bootfs in the menu.
* Reduce the helper text to one line on all screens, to make it not as visually cluttered
* Finding kernel arguments has now been moved to a function, which can be extended to support multiple OS's as the need arises


# ZFSBootMenu 0.7.7 (2020-01-08)

This release adds support for generating a syslinux/extlinux-compatible configuration file. This can be used both with Petitboot on POWER hardware and with extlinux on x86_64.


# ZFSBootMenu 0.7.6 (2019-12-31)

This is a fairly minor release, with the removal of an external VERSION file and the inclusion of a basic Makefile being the major impacting changes.


# ZFSBootMenu 0.7.5 (2019-12-24)

A previous release defaulted pool imports to read-only mode. Because of this, cloning a snapshot would fail. This release fixes that by detecting if a pool is imported as read-only, exporting it and re-importing it read-write. If the snapshot being cloned is encrypted, keys will be loaded again (from file or via prompt).

To control read-write behavior, the command line argument `read_write` has been added. If unset, this option defaults to 0, importing the pool in read-only mode. Set to 1 to enable read-write on imported pools by default.


# ZFSBootMenu 0.7.4.1 (2019-12-20)

Point release to fix issues on a fresh installation with missing target paths.


# ZFSBootMenu 0.7.4 (2019-12-20)

This release fixes a glaring integration issue with rEFInd. Unified EFI files now use the platform kernel base (vmlinux, vmlinuz, etc), with the version and EFI appended. This allows them to integrate nicely with rEFInd's boot options and kernel roll-up features.


# ZFSBootMenu 0.7.3 (2019-12-20)

This release adds the helper bin/generate-zbm which can help control the lifecycle of a the components needed to boot a system. It can generate a versioned kernel and initramfs, and/or a combined kernel/initramfs/commandline EFI executable. The helper script is able to able to do un-versioned files as well, creating initramfs-zfsbootmenu.img and then rotating that into initramfs-zfsbootmenu-backup.img when a new initramfs is created.

To better integrate with boot loaders like rEFInd, the option 'timeout' can be set on the command line when booting into the bootmenu.

A value of 0 will bypass the countdown timer and menu screens, attempting to boot the environment set by bootfs.
A value of -1 will force you into the menu system, where you can pick a boot environment, kernel, snapshot etc.
Any positive integer value will enable the countdown timer, where the system will then attempt to boot the environment set by bootfs.

The default timeout value remains at 10 seconds, consistent with previous behavior.


# ZFSBootMenu 0.7.2 (2019-12-10)

Default the creation of the initramfs to hostonly mode, to substantially reduce the size of the generated file.


# ZFSBootMenu 0.7.1 (2019-12-10)

Minor bug fix release. Correctly handle a zpool value on the command line pointing to a non-existent pool. Additionally, when trying to read a pinned kernel version, read it from the selected BE, and not the BE pointed to by `bootfs`


# ZFSBootMenu 0.7.0 (2019-12-09)

This release includes the following:

* Include documentation on how to use ZFSBootMenu on a system with native encryption.
* Add the ability to prefer a specific kernel version via `org.zfsbootmenu:kernel` set on a filesystem. Refer to 17302b7d for additional details.
* Split out functions into `zfsbootmenu-lib.sh`, with some degree of documentation
* Modify clone snapshot functionality to clone the snapshot and then discover all kernels present in it. After cloning a specific snapshot, you can now access it from the main BE menu and boot any kernel, or the one set by `org.zfsbootmenu:kernel` at the time the snapshot was taken.
* Fix a small syntax error when handling no pools being imported
* Add supporting files for xbps packaging
* Switch pools to readonly on import, for additional safety
* No longer export a pool before kexec - saving us some number of seconds on boot.
* Do not sanity check memory in kexec for faster booting


# ZFSBootMenu 0.6.5 (2019-11-16)

This is largely a bug-fix release, built on top of Linux 5.3.10 and ZFS 0.8.2 for x86_64 and ppc64le (POWER8+).

* Properly sort the list of kernels by version, so that 5.x.10 is
considered a higher version than 5.x.9
*  Correctly set a return value for all zfs load-key operations
* Greatly simplify when a BE is mounted when trying to find kernels in
/boot
* Only add a BE to the environment list if one or more kernel/initramfs
pairs were found


# ZFSBootMenu 0.6 (2019-11-06)

This release brings support for native ZoL encryption! It supports encryption on the entire pool, or enabled for a specific boot environment!

Prompting for the passphrase happens if the key needs to be loaded to boot the environment set in `bootfs` or if you escape the auto-boot screen to enter the environment/snapshot/kernel browser.

A patch is provided for 90zfs/mount-zfs.sh which detects if the keylocation is a file, and then attempts to load it from disk. If the key file is not present, and the type is passphrase, it will prompt.

The default auto-boot screen now attempts to center itself in your tty, for a slightly easier to read output.

Booting from a snapshot has been fixed - the snapshot is now correctly unmounted after a kernel/initramfs pair is located in /boot from the snapshot.


# ZFSBootMenu 0.5 (2019-10-22)

Initial release!

The dracut module has been built into an initramfs for both x86_64 and ppc64le (POWER8+) - with Linux 5.3.7. A sample grub.cfg is provided, demonstrating how to enter the boot menu. Update your pool name, and set spl_hostid based on the output of 'hostid' on your machine.

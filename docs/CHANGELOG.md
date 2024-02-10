# Changelog

## ZFSBootMenu v2.3.0 (2023-12-12)

ZFSBootMenu v2.3.0 introduces a few new capabilities and refactors some existing features.

### New features

The ZFSBootMenu hook system has been enhanced. In addition to "early setup", "setup" and "teardown" hooks, users can install "load-key" and "boot-selection" hooks to better control the unlocking of ZFS filesystems and the process of booting a selected environment. Hook installation and management has been simplified: the `zfsbootmenu_{early_setup,setup,teardown}` variables in `dracut` and `mkinitcpio` configurations have been deprecated in favor of `zfsbootmenu_hook_root`, which points to a directory containing subdirectories that correspond to each hook stage. ZFSBootMenu now includes "system" hooks that are automatically installed in every generated image; the USB-teardown and font-resizing hooks provided as `contrib` scripts are now installed as system hooks. A new command-line argument, `zbm.skip_hooks`, allows individual hooks to be skipped at runtime.

When ZFSBootMenu is unable to import any ZFS pools, it will capture and display import errors when entering an emergency shell.

The commands `reboot`, `poweroff` and `shutdown` are provided in ZFSBootMenu images, providing a convenient means to interrupt or restart the boot process from an emergency shell.

Various UI and UX enhancements improve the user experience within ZFSBootMenu:

* The `zreport` utility provides more information about the environment
* Online help now includes a "System Report" tab that displays the output of `zreport`
* Pre-built ZFSBootMenu images will no longer complain on hostid mismatches
* The main menu now shows the key on which entries are sorted

### Fixes

Chimera Linux boot environments are now properly recognized and will receive the appropriate root prefix by default.

Pre-built recovery images now include `sgdisk` and SSL certificates that will allow `curl` to communicate with HTTPS servers. The pre-built release and recovery images both include the `zbm-kcl` utility to allow convenient editing of command-line arguments for boot environments as well as ZFSBootMenu EFI bundles.

The `zbm` and `debug` commands, previously shell aliases, are now symlinks; this makes these commands accessible to users of images built with `mkinitcpio`.

Searches for kernels and initramfs images in boot environments have been improved. Although results of searches should be the same, the searches should happen slightly faster.

The `contrib/zbm-sign.pl` script now respects the `EFI.ImageDir` variable in the `generate-zbm` configuration file.

### Removal

Support for managing `syslinux` configurations with `generate-zbm`, long deprecated, has been removed. Users must now manage syslinux configurations manually.

### Significant commits in this release

* cb8dfaa - zfsbootmenu-core: show enabled/disabled hooks in zreport (Zach Dykstra)
* 3739e89 - zreport: show canmount dataset property (Zach Dykstra)
* efea0c1 - zfsbootmenu: use symlinks for two useful aliases (Zach Dykstra)
* 0d29988 - lib/zfsbootmenu-kcl: clean up argument reading (Andrew J. Hesford)
* 07d6e73 - zfsbootmenu-preinit: single-quote values written to /etc/zfsbootmenu.conf (Andrew J. Hesford)
* 23bdb71 - zfsbootmenu-ui: fix argument order when listing snapshots (Andrew J. Hesford)
* 14fb79f - zfsbootmenu-core: use new zbm-release file, make zreport pretty (Zach Dykstra)
* 691e332 - zfsbootmenu-help: add system report section to online help (Zach Dykstra)
* 9d7eba4 - Improve version handling in the repository and ZBM images (Andrew J. Hesford)
* 8f1570f - contrib/zbm-sign.pl: respect EFI.ImageDir (John Zimmermann)
* d7ebc84 - examples: modernize, install (Zach Dykstra)
* 55f08b9 - generate-zbm: remove integrated syslinux support (Zach Dykstra)
* f23fc69 - zfsbootmenu-core: fix typo in warning text (Zach Dykstra)
* 9588659 - zfsbootmenu/: tab-delimit kernel lists for boot environments (Andrew J. Hesford)
* 831d55a - releng/docker: Dockerfile parity with image-build.sh (Min Idzelis)
* 57b5572 - zfsbootmenu: remove legacy root= usage/design (Zach Dykstra)
* e93de79 - zfsbootmenu: add sysrq-based reboot/poweroff (Zach Dykstra)
* 6afe2ff - zfsbootmenu-core: remove SIGINT trap when launching e-shell (Min Idzelis)
* abf9649 - zfsbootmenu: rename UI library, normalize imports (Zach Dykstra)
* 40f7928 - zfsbootmenu-core: optimize initramfs search (Andrew J. Hesford)
* d7caa8c - releng/docker/image-build.sh: use tmpfs for XBPS cache (Andrew J. Hesford)
* 3f3e831 - zfsbootmenu: make zbm.autosize a system hook (Zach Dykstra)
* 9b348b4 - zfsbootmenu-core: disable spl_hostid warnings (Zach Dykstra)
* bd1319f - zfsbootmenu: log errors for unimportable pools (Zach Dykstra)
* 2762b7e - zfsbootmenu-core: run boot environment hooks after environment mount (Agorgianitis Loukas)
* 9524215 - releng/docker/build-init.sh: add rc.pre.d hooks (Andrew J. Hesford)
* 640af57 - Refactor user runtime hooks installation and processing (Andrew J. Hesford)
* 7045d1f - zfsbootmenu-lib: show sort key where needed (Zach Dykstra)
* ff59562 - zfsbootmenu: refactor installation, support system and user runtime hooks (Zach Dykstra)
* e5cfb46 - releng/docker/image-build.sh: improve repo and kernel selection (Andrew J. Hesford)
* 1526bb8 - zfsbootmenu-core: improve kernel searches (Andrew J. Hesford)
* 955ac2f - zfsbootmenu-core: remove trailing whitespace (Andrew J. Hesford)
* e7a3b89 - releng/docker: update Void base images (Andrew J. Hesford)
* 3682393 - releng/docker/image-build.sh: support custom XBPS repositories (Andrew J. Hesford)
* c8c9e8d - contrib/remote-ssh-build.sh: Add pool key to system mkinitcpio config (Emad Elsaid)
* 56cbbe8 - dracut, initcpio: make libgcc_s search universal (Andrew J. Hesford)
* deefabd - release,recovery: add tools to images (Zach Dykstra)
* 2431eff - zfsbootmenu-core: log error when be is locked in mount_zfs (Zach Dykstra)
* 3616009 - zfsbootmenu: add default Chimera Linux KCL (Zach Dykstra)
* 9343eb5 - zfs-chroot: small visual fixes/improvements (Zach Dykstra)

## ZFSBootMenu v2.2.2 (2023-10-24)

ZFSBootMenu v2.2.2 contains no runtime changes relative to v2.2.1. The creation of UEFI bundles (so-called unified kernel images, or UKIs) in `generate-zbm` has been updated to properly support newer UEFI stub loaders that were known to cause boot failures in the past. These changes were inspired by similar functionality in mkinitcpio and the `ukify` utility included with systemd.

### Significant commits in this release
* 9424356 - bin/generate-zbm: add .linux section last (Zach Dykstra)
* 36a0a66 - bin/generate-zbm: use mkinitcpio method to calc offsets (Zach Dykstra)

## ZFSBootMenu v2.2.1 (2023-10-13)

ZFSBootMenu v2.2.1 offers a few minor bug fixes over the prior release. More significantly, the build-container images and release assets for this version include OpenZFS 2.2.0 to provide access to upgraded pools.

All users of the binary releases or the ZFSBootMenu build container are encouraged to update to ZFSBootMenu v2.2.1 before upgrading any ZFS pools.

### Significant commits in this release
* e4102ee - zfs-chroot: load keys again after setting pool r/w (Zach Dykstra)
* 7b3dcc1 - zfs-chroot: add read-write prompt (Zach Dykstra)
* 09e4d76 - docs/man/zfsbootmenu: fix typo (Wesley H. Gimenes)
* 7532d1f - zfsbootmenu: protect stdout of main interface (Zach Dykstra)
* 6528649 - zfsbootmenu-help: use cat in place of less (Zach Dykstra)
* bf20728 - zfsbootmenu: make 'less' an optional binary (Zach Dykstra)
* d03f9de - Add dm-crypt to recovery images, so cryptsetup works (Andrew J. Hesford)
* b212b23 - zbm-builder.sh: add mount-options argument, document use (Andrew Gunnerson)

## ZFSBootMenu v2.2.0 (2023-05-21)

Perhaps the most significant change in ZFSBootMenu v2.2.0 is an overhaul of the project documentation. We are thrilled to welcome new member @classabbyamp to the project, who oversaw this substantial effort. Disparate documentation previously stored in Markdown files, the GitHub Wiki, POD files, and another git repository have now been combined into a single tree that is published on Read The Docs. The documentation is now maintained as an integral part of this repository and is published at https://docs.zfsbootmenu.org/. This includes:

* Man pages
* Run-time help pages
* Distribution installation guides
* Configuration and how-to documentation

Installation guides for Void Linux, Alpine, Debian Bullseye, Ubuntu 22.04 and openSUSE Leap are available, with similiar steps shared between the guides for easier maintenance and revision.

### New features

Kernel command-line handling for ZFSBootMenu and boot environments has received a revamp with the `zbm-kcl` tool. This comprehensive tool can modify the kernel command-line for both boot environments and for the embedded command-line in binary EFI releases. Refer to [zbm-kcl.8](https://docs.zfsbootmenu.org/en/v2.2.x/man/zbm-kcl.8.html) for additional usage details.

UEFI variable handling in ZFSBootMenu has now been normalized to be consistent between Dracut and mkinitcpio. When chrooting into a boot environment,  `efivarfs` is now mounted in the chroot. The filesystem is mounted read-only if the pool is read-only, and read-write if the pool is read-write. Additionally, if `efibootmgr` is present in the ZFSBootMenu initramfs, `efivarfs` is mounted read-write in the recovery shell.

To help users with high-DPI displays, ZFSBootMenu binary releases will now attempt to set the largest possible font size (up to 32 pixels) that ensures at least 100 text columns on the screen. Users who build their own custom ZFSBootMenu images can add [contrib/20-console-autosize.sh](https://github.com/zbm-dev/zfsbootmenu/blob/v2.2.x/contrib/20-console-autosize.sh) as an early-setup hook to achieve the same effect. Consult [zfsbootmenu.7](https://docs.zfsbootmenu.org/en/v2.2.x/man/zfsbootmenu.7.html) for instructions on configuring custom hooks.

The `generate-zbm` configuration key **Kernel.Version** now supports globs, such as `6.1.*` or `5.*`, to select the latest among a series of matching kernel versions for building a ZFSBootMenu image. The containerized build process now includes Linux versions 6.1, 5.15 and 5.10 and pre-compiled ZFS modules for each to simplify builds of custom images with recent LTS kernels.

### Fixes

A mutex to prevent infinite recursion when attempting to load keys for an encryption root is now restricted to the process that created it. This fixes an edge case where the interface launched from SSH would not be able to unlock an encryption root.

Artix is now a recognized distribution: ZFSBootMenu will specify the proper root argument for Artix boot environments.

### Significant commits in this release
* f688389 - zfsbootmenu: warn when canmount=on is set for root dataset (Zach Dykstra)
* aca5ae1 - zfsbootmenu/install-helpers.sh: hard depend on `chroot` (Andrew J. Hesford)
* dacce21 - contrib/zbm-sign.pl: add hook to sign ZBM EFI images for Secure Boot (Liam)
* da94578 - zsnapshots: recovery environment helper tool (Zach Dykstra)
* ddcee9d - generate-zbm: allow globs for kernel-version specs (Andrew J. Hesford)
* 989449c - zfsbootmenu: add zbm.kcl_override argument handler (Zach Dykstra)
* 534adcf - omit-drivers: blacklist intel screen orientation sensor (Zach Dykstra)
* 7f38b12 - zfsbootmenu-core: recognize Artix in root-prefix detection (Andrew J. Hesford)
* 84da18e - contrib/: expand font setting capabilities (Zach Dykstra)
* f78f723 - zfsbootmenu: manage efivarfs when needed (Zach Dykstra)
* c28a44f - zbm-kcl, zbm-efi-kcl: unify, allow streaming EFI modifications (Andrew J. Hesford)
* d73fad8 - UEFI: improve stub handling (Zach Dykstra)
* 5b61268 - releng: add kpartx and wipefs to recovery images (Zach Dykstra)
* c578ef5 - Key management: properly normalize Booleans, make cache mutex per-PID (Andrew J. Hesford)

## ZFSBootMenu v2.1.0 (2022-12-19)

### Deprecated features

* `syslinux` support as a core part of `generate-zbm` will be removed in the next release. [contrib/syslinux-update.sh](https://github.com/zbm-dev/zfsbootmenu/blob/master/contrib/syslinux-update.sh) should be used to create `syslinux.cfg` moving forward. Refer to the script for usage documentation.
* Awareness of platform endianness when writing `/etc/hostid` was rendered moot when support for `skim` was removed because `fzf` is only supported on little-endian systems. All hostid writes assume little-endian byte order by default.

### New features

* The command line option `zbm.prefer` has been extended with a `!!` marker to import exactly one pool when multiple are available on a system. Refer to [docs/man/zfsbootmenu.7.rst](https://github.com/zbm-dev/zfsbootmenu/blob/master/docs/man/zfsbootmenu.7.rst) for more details.
* Users of the binary releases are now able to use their own custom hooks with the new `zbm.hookroot` command line option. Using this, a partition and directory specification can be provided which allows for additional scripts to be loaded at runtime. Refer to [docs/man/zfsbootmenu.7.rst](https://github.com/zbm-dev/zfsbootmenu/blob/master/docs/man/zfsbootmenu.7.rst) for more details.
* [contrib/remote-ssh-build.sh](https://github.com/zbm-dev/zfsbootmenu/blob/master/contrib/remote-ssh-build.sh) has been provided by a new contributor. This script helps ease the creation of a custom EFI file with an embedded SSH server and keys.
* A global application header has been added to highlight the pages that are available and the currently selected page.
* Unless explicitly configured, `generate-zbm` will now default to `dracut` but fall back to `mkinitcpio` when it cannot find `dracut` in the path.
* The build container `ghcr.io/zbm-dev/zbm-builder` has been substantially improved, making it easier to manage custom images built in a controlled, compatible environment using podman or docker.

### Fixes

* On some systems, Dracut was incorrectly using `dash` where `bash` should be used. Forbidding the inclusion of `dash` with Dracut resolves this issue.
* The `drm` Dracut module has been blacklisted. ZFSBootMenu should never attempt to load firmware for video cards.
* When using ZFSBootMenu to pin a kernel, ensure that an anchor is attached to the end of the pin. This resolves incorrect matches on systems that have unversioned kernels.
* To avoid a potential conflict between ZFS pool names and files/directories created by ZFSBootMenu, all detected boot environment mountpoints have been moved to a dedicated `environments/` sub-directory.

### Significant commits in this release
* 8e6ca4a - set_default_kernel: properly clear default when no kernel is specified (Andrew J. Hesford)
* 0b40f44 - interface: enable left/right arrow key navigation (Zach Dykstra)
* 235eb17 - Stop installing zpool.cache (Andrew J. Hesford)
* 5427883 - Improve containerized builds (Andrew J. Hesford)
* c023517 - Automatically select initramfs generator when not forced (Andrew J. Hesford)
* 6223804 - Update artifact uploader to latest version (Zach Dykstra)
* 00ef434 - Add/use border label feature flag (Zach Dykstra)
* 562b14a - Fix booting test VMs on some hardware (Zach Dykstra)
* 8d3bbff - Fix kernel selection after introducing $BASE/environments (Alexander Lobakin)
* b743893 - contrib/README.md: document contrib scripts (Andrew J. Hesford)
* a3f15ed - generate-zbm: deprecate syslinux support (Andrew J. Hesford)
* 9f85003 - Include the OpenSSH client in recovery images (Zach Dykstra)
* 91900d3 - Explicitly require bash, blacklist dash (Andrew J. Hesford)
* 3399f4b - Move dataset mountpoint to $BASE/environments/ (Zach Dykstra)
* 7eb7780 - Allow imports of hooks from external sources at runtime (Andrew J. Hesford)
* 57b46a2 - Extend capabilities of zbm.prefer (Zach Dykstra)
* af1c74b - Remove diff from early days of playing around (Zach Dykstra)
* 3da5547 - Center key bind text on horizontal layout fzf screens (Zach Dykstra)
* df8ab05 - Support busybox as /bin/sh in chroot (Zach Dykstra)
* 2fa207e - fix: ensure $uefi_stub is defined before checking if it is a file (Zach Dykstra)
* 906ce3b - Add anchor to end of string when pinning a kernel (Zach Dykstra)
* 9c91afa - Make default efi path distro agnostic (gardar)
* 333b6d8 - Wrapper Build Script for ZBM with SSH access (Gerhard Roethlin)
* 05dbf11 - Show /etc/zbm-commit-hash in zreport (Zach Dykstra)
* d4b35a0 - zbm-build.sh: don't upgrade packages when installing custom software (Andrew J. Hesford)
* 10e3624 - Exploit common configurations for recovery/release images (Andrew J. Hesford)
* 1be8ed0 - Drop drm module from standard dracut config (Andrew J. Hesford)
* 9b57d8a - testing: move Ubuntu to 22.04 LTS, make column available to Debian/Ubuntu (Andrew J. Hesford)
* feb6a26 - documentation: provide a link to the wiki (Zach Dykstra)
* f2d3336 - Add a contrib script to snapshot the BE prior to boot (Zach Dykstra)

## ZFSBootMenu v2.0.0 (2022-06-28)

ZFSBootMenu 2.0.0 introduces a major internal reorganization that allows images to be built with initramfs generators other than dracut and includes some helpful command-line utilities. This release is based on Linux 5.10.125 and ZFS 2.1.5.

### New features

* Dracut is now optional; ZFSBootMenu images may currently be built with mkinitcpio
* Generalizations to support mkinitcpio should also apply to, *e.g.*, initramfs-tools, although installation hooks for initramfs-tools have not (yet) been written
* A new utility, `zbm-efi-kcl`, provides the ability to edit the kernel command-line embedded in a ZBM EFI bundle rather than requiring regeneration of the bundle
* A new utility, `zbm-builder.sh`, provides a simple interface for creating custom, local images using the official ZBM build container; it is now possible to build local images without installing ZBM or its Perl dependencies

### Fixes

* Video drivers are now omitted from images by default to avoid GPU initialization issues in the final boot environment
* General fixes to shell functions were made in support of using busybox in mkinitcpio images
* The online command-line editor now provides an option to revert to the default

### Significant commits in this release

* 8933a57 - Basic EFI KCL editor (Zach Dykstra)
* ada36c8 - Include cryptsetup in recovery images (Zach Dykstra)
* f1b0270 - Include cryptsetup in containarized builds (Grzegorz Uriasz)
* fd52d7c - Omit video drivers by default (Zach Dykstra)
* 65dd0cd - Add option to revert to default KCL via ctrl-t in draw_be (Zach Dykstra)
* 632b24f - Add special escape sequences to PS1 (Zach Dykstra)
* 3d9f57b - Build recovery images in CI/CD (Zach Dykstra)
* 9368171 - Accept any root= value as valid (Zach Dykstra)
* 7982971 - zbm-builder.sh: support custom build/source paths and hooks (James R. Todd)
* fc83894 - Document scrolling keys in help viewer (Zach Dykstra)
* 6f09d39 - Fix broken links (Jip de Beer)
* 64936f3 - Add minimal documentation to ESP sync hook (Zach Dykstra)
* d559458 - Add BUILD.md, a quick-start containerized build guide (James Todd)
* 1aca5d1 - Bug fixes and use local repository option for zbm-builder.sh (James Todd)
* 8b1aade - Make the emergency shell slightly fancy (Zach Dykstra)
* 5a5ab0b - Write data to console to recalculate size (Zach Dykstra)
* eac0547 - install-helpers.sh: explicitly require setsid (Andrew J. Hesford)
* dbd9642 - Replace 'tr' with bash string manipulation (Zach Dykstra)
* 8916a10 - Update luks-unlock.sh to work with current libraries (Zach Dykstra)
* 33883e5 - zfsbootmenu-core.sh: drop preload_be_cmdline, improve KCL caching (Andrew J. Hesford)
* 7548af5 - zbm-kcl: remove dracut from ZBM_MODULEDIR warning (Andrew J. Hesford)
* 306f36b - Fix install location for common module files (Zach Dykstra)
* 644b0f1 - Use an early-setup hook to force console init in release images (Andrew J. Hesford)
* ec89a7c - Use column to layout footer (Zach Dykstra)
* 2bd6757 - generate-zbm: remove INI migration support (Zach Dykstra)
* 65167e6 - Define all ZBM requirements in install-helpers.sh (Andrew J. Hesford)
* 812f9b4 - Remove support for deprecated KCL sources (Andrew J. Hesford)
* 3dcaa88 - Improve container-based builds and support mkinitcpio images (Andrew J. Hesford)
* f93687f - Annotate mkinitcpio.conf to explain ZBM specifics (Andrew J. Hesford)
* 91b4b3b - De-prioritize Dracut as the primary generator (Zach Dykstra)
* af34fa9 - Support building mkinitcpio images in generate-zbm (Andrew J. Hesford)
* 50a2da4 - General fixes to support busybox in mkinitcpio images (Andrew J. Hesford)
* 1fe8c4c - Add support for mkinitcpio (Andrew J. Hesford)
* e1bd708 - zbm-builder.sh: add script to build custom images using GHCR container (Andrew J. Hesford)
* 20a8ac7 - Add manual page for zbm-kcl (Andrew J. Hesford)


## ZFSBootMenu v1.12.0 (2022-01-25)

This release brings multiple changes to how ZFSBootMenu works at run-time. These changes were introduced in an effort to:

1. Reduce the ZFSBootMenu startup time,
2. Remove dependencies on Dracut-specific helper functions, and
3. Make ZFSBootMenu more modular and more easily maintained.

Prior to this release, the only Dracut helper functions in use were those that retrieve command-line arguments to dynamically configure ZFSBootMenu. These have all been replaced by internal functions that are both more correct and roughly an order of magnitude faster.

With the help of the [flamegraph](https://github.com/brendangregg/FlameGraph) visualization tool, multiple unnecessary Dracut modules have been pruned from the binary releases. The net effect of these changes is a large decrease in the time spent booting to either the menu or directly to a boot environment.

ZFSBootMenu v1.12 is expected to be the last release series before ZFSBootMenu v2.0. The internal changes and dramatically reduced dependence on Dracut will allow ZFSBootMenu v2.0 images to be built using either dracut or mkinitcpio.

### Deprecated features

* Support for `skim` has been removed. ZFSBootMenu now requires `fzf` for all menu functionality.
* Support for using `/etc/default/grub` and `/etc/default/zfsbootmenu` for boot environment kernel command line parameters will be removed in the next release.

### Fixes

* Use `kexec --kexec-syscall-auto` to try multiple different ways to load a kernel
* Change the release files names to better indicate to rEFInd that they are Linux kernels
* `root=` is always removed/suppressed when passing a commandline into the boot environment
* More kernel commandline parameters are validated for correctness

### New feaures

* Add the `zbm-kcl` userland tool to view and edit boot environment kernel command lines
* `generate-zbm` can now execute user hooks before and after an initramfs or EFI bundle has been created
* Teardown hooks now have access to variables indicating which boot environment, kernel and initramfs were selected
* We now provide `recovery` builds that include networking and a few disk-related tools
* Buildah is now used to create build images
* Countdown timers now have colored text by default

###  Significant commits in this release

* bd736f1 - Add a shell utility to modify and review KCL properties (Andrew J. Hesford)
* 466e4d2 - Allow rollbacks from the snapshot menu (Andrew J. Hesford)
* b9c4ed9 - Add Alpine to the ZBM test suite (Andrew J. Hesford)
* 2c8eacc - Add support for early/late hooks in generate-zbm (Zach Dykstra)
* 1ca3cf4 - Define BE selection variables in teardown hook environment (Andrew J. Hesford)
* 89b6273 - Enable profiling framework in core ZFSBootMenu tools (Zach Dykstra)
* 46b0eb9 - Completely rewrite KCL handling (Andrew J. Hesford, Zach Dykstra)
* 4b836f3 - Generate release and recovery image builds (Zach Dykstra)
* 6789ee2 - Provide, and use, a buildah script to construct zbm-builder images (Andrew J. Hesford)
* 70bad38 - Add initial boot-environment guide (Andrew J. Hesford)
* 4b836f3 - Generate release and recovery image builds (Zach Dykstra)
* 044df51 - Separate core library routines from main UI routines (Andrew J. Hesford)

## ZFSBootMenu v1.11.0 (2021-10-31)

### Updated defaults

* The chroot hot-key has been changed to `MOD+J` to avoid a key conflict with the usage of `CTRL+I`.

### Deprecated features

* Support for reading the KCL from /etc/default/zfsbootmenu or /etc/default/grub will be removed in a future release. During the transition period, ZFSBootMenu will attempt to automatically convert a deprecated KCL configuration to the org.zfsbootmenu:commandline property.

### Fixes

* The Makefile now correctly installs all files (this fixes the missing help pages)
* Make the width of the count down menu consistent as digits are dropped from the timer
* Remove a spurious function call in the preview renderer
* Where possible, prefer built-in Bash regex support over forking to grep
* Remove uses of basename, prefering Bash string manipulation
* Properly find the zpool executable when creating an initramfs
* Set a consistent environment for SSH and recovery shells
* Set default columns and rows for serial consoles when none are provided
* Improve the reliability of detecting which libgcc_s.so to install
* Set keylocation and a corrected encryption root for full-copy clones

### New features

* Allow taking over a running instance of ZFSBootMenu via `zbm`
* Create a docker/podman image, based on Void Linux, that can be used to create ZFSBootMenu images
* Allow diffing a snapshot with another snapshot, instead of just with the current state of the filesystem
* Add early hooks, just after kernel modules have been loaded but before any pools have been imported
* org.zfsbootmenu:keysource can now be an arbitrary ZFS filesystem instead of another boot environment
* Snapshots can now be created, providing a starting point for a new boot environment
* `zreport` is available in the recovery shell, which can provide details-at-a-glance for bug reports
* The `testing/` infrastructure has been updated to allow the installation of multiple distributions in one command
* The Debian testing environment has been updated to Bullseye
* EFI bundles can be built and tested under `testing/`

### Significant commits in this release
* 32f138f - Try to inherit key (encryptionroot) in duplicate_snapshot (Andrew J. Hesford)
* 357aa5e - Make keylocation of target match that of source in duplicate_snapshot (Zach Dykstra)
* c048ead - testing: move debian to bullseye (Andrew J. Hesford)
* 7bb154d - testing: allow installation of multiple distros in one setup run (Andrew J. Hesford)
* 8fab2b5 - Rework GitHub actions to also build assets on push (Zach Dykstra)
* 8922f87 - Add zreport function (Zach Dykstra)
* f0d402c - Support creating EFI bundles in run.sh, along with booting them. (Zach Dykstra)
* 2c58479 - Improve search for libgcc_s in module-setup.sh (Andrew J. Hesford)
* 726894f - Default stty cols/rows values for serial consoles (Zach Dykstra)
* 78656b0 - Small fixes for SSH usage (Zach Dykstra)
* 0e14c7b - Update zfsbootmenu.7 to reflect new org.zfsbootmenu:keysource behavior (Andrew J. Hesford)
* 891e44a - Allow snapshot creation / move logic to function (Zach Dykstra)
* d208103 - Make cache_key aware of mountpoints on key sources (Andrew J. Hesford)
* 2d03ff5 - Remove explicit path to zpool ldd check (Zach Dykstra)
* 29a1049 - Deprecate KCL in /etc/default/{zfsbootmenu,grub} (Andrew J. Hesford)
* c2a1bee - Support early hooks, add example luks-unlock.sh (Zach Dykstra)
* 62f7315 - Enable snapshot <> snapshot diffing (Zach Dykstra)
* c920c76 - Replace mod+i with mod+j (Zach Dykstra)
* a79b9d0 - zkexec: recovery shell arbitrary kexec wrapper (Zach Dykstra)
* 8d4d776 - Makefile: recursively install dracut module (Andrew J. Hesford)
* c1feb56 - recovery shell quality of life improvements (Zach Dykstra)
* 5876ca9 - Create a global debug/trace log viewer (Zach Dykstra)
* 83b1766 - Overhaul, generalize containerized build scripts (Andrew J. Hesford)
* cfa0455 - releng/make-binary.sh: use containerized image builds (Andrew J. Hesford)
* 4166967 - Add Dockerfile and Compose service to build ZBM images (Thomas Oster)
* 687295a - Allow zfsbootmenu to takeover a running instance (Zach Dykstra)
* 9000687 - Start adding aliases for missing niceties (Zach Dykstra)
* 804ef02 - Make sure feature flags are available everywhere (Zach Dykstra)
* 739540a - Error out in testing if machine type isn't known to run.sh. (Érico Nogueira Rolim)

## ZFSBootMenu v1.10.1 (2021-07-04)

ZFSBootMenu 1.10.1 brings a pair of fixes to issues seen in the wild. 

### Fixes

* Remove a spurious warning when `generate-zbm` incorrectly detected a mismatch between `/etc/hostid` and the run-time `spl_hostid` SPL module parameter.
* Fix a race condition between ZFSBootMenu and udev when attempting to load ZFS/SPL kernel modules, resulting in an incorrect drop to a recovery shell. 

### Significant commits in this release

* 2a9a6ab - Relax insmod spl failures, try to load zfs.ko (Zach Dykstra)
* f657717 - generate-zbm: fix hostid comparison (Andrew J. Hesford)

## ZFSBootMenu v1.10.0 (2021-06-27)

ZFSBootMenu 1.10.0 brings some minor new features and some behavior changes that should improve the booting and configuration experience. Notably, some default behaviors have changed in this release. Read on for details about how this may impact your configuration.

### Updated defaults

Previous releases have had `zbm.import_policy=strict` and `zbm.set_hostid=0` set by default. Starting with this release, the default values are `zbm.import_policy=hostid` and `zbm.set_hostid=1`. `zbm.import_policy=hostid` can help ZFSBootMenu automatically and safely import a pool when the wrong hostid is provided. `zbm.set_hostid=1` passes the hostid used to import the pool to the boot environment, ensuring that it can also correctly import the pool.

Please refer to [Command-Line Parameters](https://github.com/zbm-dev/zfsbootmenu/blob/master/docs/man/zfsbootmenu.7.rst#command-line-parameters) for a compete description of both of these feature flags.

### Fixes
* When no hostid is provided or discoverable, use `0x00bab10c` instead of `0x0`.
* Force SPL to use `/etc/hostid` and always ensure that a valid hostid is stored in the file.
* Blacklist Plymouth; the splash screens it draws interferes with the ZBM interface.
* Persist runtime configuration to a file that is used when the interface is launched normally or through SSH.

### New features
* When exiting the diff browser, exit back to the snapshot list with the snapshot selection preserved.
* Set a hostname in ZFSBootMenu so that it shows up in the pool history for read/write operations.
* When generating an initramfs, warn if `/etc/hostid` doesn't match `spl_hostid` provided as a module parameter to SPL.
* Support `console=` kernel parameters with a `,speed` suffix. This is normally used when setting a serial port as the machine console.
* Add a shortcut key to remove the pinned kernel value for a boot environment.

### Allow references to parent properties in org.zfsbootmenu:commandline

Any reference to `%{parent}` in `org.zfsbootmenu:commandline` will be replaced with the value of the same property on the parent filesystem (with parent references above recursively expanded), allowing easy specification of common options at a mutual parent of two BEs and overrides or additions of individual options per-BE. The value of `%{parent}` is always an empty string on a root filesystem.

This is not intended to be sophisticated, and `%{parent}` appearing within other words will be replaced regardless. The assumption is that `%{parent}` is unique enough and will not conflict with real KCL options, so dumb global replacement is sufficient.

### zpool import process improvements

The existing `zbm.prefer` option has been extended to support defining a mandatory pool. Append `!` to the pool name to indicate that the specific pool MUST be imported before any other pool imports will be attempted.

* `zbm.prefer=zroot!` will require that `zroot` be imported on boot.

Between pool import attempts, `zbm.import_delay` (default of 5 seconds) controls how long to pause. During this delay window, the escape key can be used to access a full recovery shell.

Either one of `spl_hostid` or `spl.spl_hostid` can be provided on the ZFSBootMenu kernel command line, in either hex or decimal format. The parameter value is checked to ensure that it's either valid hex or decimal, and then normalized to an 8 digit hex value.

Additional steps have been taken to ensure that SPL can be loaded if an invalid `spl.spl_hostid` value is provided on the kernel command line. A more strict test is now used to determine if the ZFS kernel module has been loaded and drop to a recovery shell if not.

### Significant commits in this release
* c759df9 - For musl/non-dracut compat, change default hostid to non-zero value (Zach Dykstra)
* 8886db3 - Force spl.spl_hostid=0 when matching hostid (Andrew J. Hesford)
* 24e6e6a - Blacklist plymouth; it directly conflicts with how we manage the tty (Zach Dykstra)
* 9875115 - Store options from KCL in a file for easy sourcing (Andrew J. Hesford)
* 98f3164 - Use fzf's execute[] function to render draw_diff (Zach Dykstra)
* 64bd359 - Set a hostname in ZBM, check if spl.spl_hostid matches /etc/hostid (Zach Dykstra)
* 40dd0e3 - Small quality of life improvements (Zach Dykstra)
* 635d140 - Add keyboard shortcut to remove pinned kernel (Zach Dykstra)
* 04f5b87 - Allow references to parent properties in org.zfsbootmenu:commandline (Andrew J. Hesford)
* 5142aa1 - Support pool import retries (Andrew J. Hesford)
* e2caa81 - Improved pool imports (Andrew J. Hesford)
* 31cc1b3 - Validate spl_hostid, control loading spl.ko (Zach Dykstra)
* ccfc92c - Change ZBM hostid handling defaults (Zach Dykstra)

## ZFSBootMenu v1.9.0 (2021-03-29)

This release is dedicated to the late Jürgen Buchmüller (@pullmoll), a major contributor to the Void Linux project. Although ZFSBootMenu strives to support as many Linux distributions as possible, Void Linux is the distribution of choice for the entire ZFSBootMenu team. We have benefited greatly from pullmoll's enduring commitment to Void Linux. He will be missed.

### Fixes

* Snapshot duplication now carries over ZFS properties from the source (cloning has always copied properties)
* When forcing a pool read-write via MOD+W, the screen is now cleared before a password prompt
* Prompts in Arch/Ubuntu/Debian chroots are now correctly set
* Build-time checks for version-specific flags in fzf/sk/dmesg improve compatibility with older versions found on Debian and Ubuntu
* Add `stty` to the list of required binaries
* When `generate-zbm` is executed with the `--debug` flag, `-q` is no longer passed in to Dracut
* When possible, try to let Dracut determine the path to the EFI stub file. The path can be explicitly specified by setting `EFI.Stub` in `config.yaml`
* Update the list of allowed characters in a ZFS filesystem name; removing `,` and adding `:`
* Use the Dracut built-in `inst_rules` to install udev rules, instead of hard-coding a file path
* Correctly set a `root=` prefix for Gentoo systems
* Improve kernel version detection in unversioned file names
* Update documentation to clarify driver exclusions and teardown hooks

### Major New features

### `hostid` configuration assistance
A pair of new features have been developed to combat the delicate dance sometimes required to synchronize `hostid` in the boot environment (BE), the initramfs for the BE, and the initramfs for ZFSBootMenu. Both of these are controlled by ZFSBootMenu kernel command line options.

Set `zbm.import_policy=hostid` to allow run-time reconfiguration of the SPL hostid. If a pool is preferred via `zbm.prefer` and the pool can not be imported with a preconfigured hostid, the system will attempt to adopt the hostid of the system that last imported the pool. If a preferred pool is not set and no pools can be imported using a preconfigured hostid, the system will adopt the hostid of the first otherwise-importable pool. After adopting a detected hostid, ZFSBootMenu will subsequently attempt to import as many pools as possible.

Setting `zbm.set_hostid` will cause ZFSBootMenu to set the `spl.spl_hostid` command-line parameter for the selected boot environment to the hostid used to import its pool. The SPL kernel module will use this value as the hostid of the booted environment regardless of the contents of `/etc/hostid`. As a special case, if the hostid to be set is zero, ZFSBootMenu will instead set `spl_hostid=00000000`, which should be used by dracut-based initramfs images to write an all-zero /etc/hostid in the initramfs prior to importing the boot pool.

### Minor new features

### Boot environment / snapshot sorting
The main boot environment screen and snapshot list screen can now be sorted by multiple criteria. By default, these listings are sorted by name. One of `zbm.sort_key=name`, `zbm.sort_key=creation`, or `zbm.sort_key=used` can be set on the command line to change the default used. `MOD+O` can be pressed at run time to change the sort order to the next in the list.

### Helper functions in the recovery shell

The internal `zfsbootmenu-lib.sh` library is now sourced by default in the recovery shell. This makes a number of helper functions available for general use.

### Combined command line printer

Since `Dracut` can find command line options from multiple places, it can be difficult to determine which option was used to control bootloader behavior. The command `zbmcmdline` will show the command line as seen by Dracut.

### Shorcut key layout improvements

Instead of flowing the helper key text to the width of the screen, shortcut key text is now arranged in one or more columns. Low resolution screens or terminals with small dimensions will use a single column to show the text. As the terminal dimensions increase, text will be laid out in up to a maximum of three left-aligned columns.

### Logging system

ZFSBootMenu has an internal logging system backed by `/dev/kmsg` and `dmesg`. Logging is now enabled throughout the entire system, tracking both `debug` level messages as well as `warnings` and `errors`. When a warning or error condition has occurred, a yellow `[!]` or red `[!]` notification will appear in the upper left of the screen. Pressing `MOD+L` will access this logging system, allowing you to easily see these messages.

To aid in debugging issues, debug logging has been added in all of the internal library functions. These messages can be enabled by setting `loglevel=7` on the ZFSBootMenu command line.

### Binary release for x86_64

Binary releases in the form of a standalone EFI file and a kernel/initramfs pair for `x86_64` will now be made available with each future tagged release. To allow for the most compatiblity with the myriad system configurations out there, a few features will be embedded in the builds:

* `zbm.import_policy=hostid`
* `zbm.set_hostid`
* [xhci-teardown.sh](https://github.com/zbm-dev/zfsbootmenu/blob/master/contrib/xhci-teardown.sh)

The EFI binary can be used as a recovery tool by naming it `BOOTX86.EFI` and adding it to an `EF00` partition on a USB drive. It can also be used as a drop-in bootloader for your system without needing to locally build a copy. See [UEFI Booting](https://docs.zfsbootmenu.org/en/latest/general/uefi-booting.html#booting-the-bundled-executable) for example `efibootmgr` commands.


### Other changes

Some command line options have now been deprecated with the inclusion of `zbm.import_policy`. See [zfsbootmenu(7)](https://github.com/zbm-dev/zfsbootmenu/blob/master/docs/man/zfsbootmenu.7.rst#deprecated-command-line-parameters).

### Testing improvements

* Ability to install Arch / Ubuntu / Debian / Void / Void-musl on ZFS, in a VM, with a single command
  * This is huge.
* Verify that ZBM builds on Arch / Ubuntu / Debian / Void / Void-musl
* Verify that ZBM built on any distro boots any other distro
* Improvments to `run.sh` and `setup.sh` testing scripts to simplify usage

### Significant commits in this release
* fadfd0f - Use --props and --raw when send | recv duplicating (Andrew J. Hesford)
* 0a4b1f7 - Use signify to sign binary assets (Andrew J. Hesford)
* 98cfc69 - Show if BE is encrypted, add path to chroot prompt (#157) (Zach Dykstra)
* 848bfc9 - Do not drop to emergency shell if zbm.preferred cannot be imported (Andrew J. Hesford)
* fd94635 - Fix PS1 in arch/debian/ubuntu, set custom prompt in emergency shell (#151) (Zach Dykstra)
* dee6228 - Support older versions of fzf/sk/dmesg (Zach Dykstra)
* 6e28f42 - Non-zero return from chroot should be debug info, not an error (Andrew J. Hesford)
* 82ab9a7 - Add `stty` to required exectables in module-setup.sh (Andrew J. Hesford)
* f962f50 - Use configurable destinations for all paths in Makefile (Andrew J. Hesford)
* 03a38b5 - Column view for help key footers (Andrew J. Hesford)
* 951111e - Add support to discover and assume a hostid, as well as fix arguments passed to a BE (#147) (Zach Dykstra)
* 29cf15c - Logging lifecycle (#146) (Zach Dykstra)
* 629346f - Automagically source zfsbootmenu-lib in emergency shell (Zach Dykstra)
* 73dc5c2 - Move more helper functions to -lib, cleanup scripts (#144) (Zach Dykstra)
* 44ed892 - Allow BE and snapshot sorting by different criteria  (#143) (Zach Dykstra)
* 9afa8b4 - comma is invalid, colon is valid (Zach Dykstra)
* a99a8de - Update README.md to explain driver exclusions and teardown hooks (RoundDuckKira)
* 5ac481f - Use inst_rules to install rule programs (Witaut Bajaryn)
* 6cf753f - Use genkernel root prefix by default on Gentoo (#139) (Witaut Bajaryn)
* a6e02c0 - Only specify `--uefi-stub` when EFI.Stub is configured (Andrew J. Hesford)
* 893cbe9 - Improve kernel version detection. (Andrew J. Hesford)
* 8db6d8f - README: Describe more Perl dependencies (#134) (Witaut Bajaryn)

## ZFSBootMenu v1.8.1 (2021-01-12)

Happy New Year! ZFSBootMenu 1.8.1 provides a few minor enhancements and bug fixes.

### Fixes
* Properly handle encryption keys as raw devices rather than normal files. (#127)
* Improve detection of latest kernels when `/boot` contains some unversioned kernel files. (#128)
* Accept `Ctrl` and `Ctrl-Alt` as hotkey modifiers in addition to `Alt` to fix issues with some non-US keymaps. (#124)
* Everywhere a chroot hotkey is offered, use the same hotkey.

### New features
* Add hard wraps to the hotkey menus to improve clarity; ignored for small screens.
* In the snapshot list, add an option to jump into a read-only chroot for that snapshot.
* The `force_import` and `timeout` kernel command-line options are now expected to be `zbm.force_import` and `zbm.timeout`; the old forms are deprecated but will continue to work for the forseeable future.
* New `zbm.show` and `zbm.skip` command-line options force the menu to appear or be skipped if `zbm.timeout` is not also set.

### Significant commits in this release
* ab95346 - Expect names of the form <prefix>-<version> when finding latest kernel (Andrew J. Hesford)
* 798fce8 - Normalize tests for paths. (Andrew J. Hesford)
* d02865e - Change chroot keys, add help text (#126) (Zach Dykstra)
* 83c58b2 - Support Ctrl and Ctrl-Alt in addition to Alt as keybind modifiers (Andrew J. Hesford)
* 70c3d70 - Namespace our KCL args, organize parsing (#120) (Zach Dykstra)
* c1d6ce5 - Support chroot'ing into a snapshot (Zach Dykstra)
* 7a63beb - Support for hard wrap points in header_wrap (Andrew J. Hesford)

## ZFSBootMenu v1.8.0 (2020-12-15)

ZFSBootMenu 1.8.0 offers a significant list of new features, fixes and general improvements.

### Fixes
* When duplicating snapshots, the process can now be interrupted with SIGINT (Ctrl-C).
* Availability of sufficient free space is confirmed before attempting snapshot duplication.
* The `generate-zbm` command now ensures that the target directory for boot images has sufficient space, rather than copying partial and generally broken files.
* Because ZFSBootMenu never modifies filesystem contents, ZFS filesystems are always mounted read-only, even if the pool is writable.
* Changes to the handling of encryption keys correctly handle some corner cases, such as duplicating a snapshot of a filesystem with a different encryptionroot than its parent.

### New features
* Colored text and timed messages are used to bring emphasis to important messages presented by ZFSBootMenu.
* Extensive logging to the kernel ring-buffer has been enabled throughout ZFSBootMenu, with verbosity controlled by the `loglevel` kernel-command-line argument.
* Much of the core menu functionality has been separated into a standalone `zfsbootmenu` program on the initramfs, allowing the menu to be accessed over SSH using something like the [dracut-crypt-ssh](https://github.com/dracut-crypt-ssh/dracut-crypt-ssh) module.
* Boot images can be configured to include [tmux](https://github.com/tmux/tmux), allowing the boot menu to be presented in a multi-pane, detachable view. This is primarily aimed at development/debugging efforts. See descriptions of the `zbm.tmux` command-line option and the `zfsbootmenu_tmux` dracut option in the [zfsbootmenu(7)](https://github.com/zbm-dev/zfsbootmenu/blob/master/docs/man/zfsbootmenu.7.rst) manual page.
* ZFSBootMenu can now execute arbitrary, user-supplied "setup" hooks before the menu is displayed and "teardown" hooks immediately before jumping into a selected boot environment. See descriptions of the `zfsbootmenu_setup` and `zfsbootmenu_teardown` dracut options in the [zfsbootmenu(7)](https://github.com/zbm-dev/zfsbootmenu/blob/master/docs/man/zfsbootmenu.7.rst) manual page.
* Encryption keys can now be cached by pointing the `org.zfsbootmenu:keysource` property of a ZFS encryptionroot to a specific filesystem. When ZFSBootMenu attempts to load a key from a `file://` location, it will first attempt to load the key at that location relative to the filesystem specified by `org.zfsbootmenu:keysource`. If this succeeds, ZFSBootMenu will retain a copy of the key in the initramfs so that subsequent need for the key (for example, when re-importing a pool read-write to set default boot options or duplicate a snapshot) will not require re-entry of the passphrase. See descriptions of the `org.zfsbootmenu:keysource` ZFS property in the [zfsbootmenu(7)](https://github.com/zbm-dev/zfsbootmenu/blob/master/docs/man/zfsbootmenu.7.rst) manual page.
* The `Alt+C` hot key provides the means to chroot into a selected boot environment. If the pool is mounted read-write, the chroot will be writable, allowing recovery operations directly from ZFSBootMenu.

### Significant commits in this release
* 8ffe139 - Add a keybind for zfs-chroot, rework script with -lib in mind (Zach Dykstra)
* 2c3e9b5 - Support configurable, opt-in caching of key files (Andrew J. Hesford)
* 45d0066 - Add zlog() logging helper, along with debug-level logging (Zach Dykstra)
* 47aa434 - Add support for richer setup and teardown hooks (Andrew J. Hesford)
* 88818a9 - Support optional "teardown" script to run before kexec (Andrew J. Hesford)
* 2045315 - Optionally launch under tmux (Zach Dykstra)
* 7f71d4f - Mount ZFS filesystems readonly (Andrew J. Hesford)
* d559b96 - Improve key handling (Andrew J. Hesford)
* ee468aa - Initial split of core menu logic from initialization (Andrew J. Hesford)
* 25baa48 - Log dracut command, add man page documentation (Zach Dykstra)
* 3f02b8f - Prevent copying of partial files when target volume is full (Andrew J. Hesford)
* 258d18a - Merge fuctionality of createInitramfs and unifiedEFI (Andrew J. Hesford)
* 4b6e9ae - Add subroutine for debug logging (Zach Dykstra)
* 82bbdc4 - Rely on local IFS override instead of global changes (Zach Dykstra)
* 402474b - Make alt-w a toggle between R/O and R/W imports (Andrew J. Hesford)
* 953c724 - Richer color handling in timed_prompt (formerly warning_prompt) (Andrew J. Hesford)
* eb39ea6 - Show countdown in warning_prompt, use to display auto-boot countdown (Zach Dykstra)
* f10e7e8 - Rough avail space validation in duplicate_snapshot (Zach Dykstra)
* bc0e117 - Move duplicate to sub shell, exit on sigint (Zach Dykstra)

## ZFSBootMenu v1.7.1 (2020-11-18)

This is a minor bug-fix release.

### Fixes
* When ZFSBootMenu fails to import any usable pools on startup and drops to an emergency shell, the user can now manually import a pool if possible and exit the shell to attempt to continue the boot process. Previously, a reboot was required to retry the boot process.
* An oversight in the loading of encryption keys caused a harmless error message to be displayed above the password prompt. This oversight has been fixed and the error no longer appears.
* Changes made to the handling of `/etc/hostid` in the ZFSBootMenu dracut module in anticipation of similar changes in the upcoming OpenZFS 2.0.0 release. This caused inconsistent behavior on systems using the musl C library with current versions of ZFS on Linux, resulting in potentially unbootable systems without forcing the `spl_hostid` command-line parameter. Now, the ZFSBootMenu dracut module attempts to discover the installed version of ZFS and behave consistently.

### Significant commits in this release
* 940cd4c - Fall back to legacy hostid creation for ZFS < 2.0 (Andrew J. Hesford)
* 6cc0076 - Fix key_wrapper calls with out CLEAR_SCREEN defined (Zach Dykstra)
* 65a1a33 - Loop the emergency shell when initial pool imports fail (Andrew J. Hesford)

## ZFSBootMenu v1.7.0 (2020-11-15)

In addition to a bug fixes, this release targets refinements that improve usability and offer contextual help within the menus.

### Fixes
* ZFSBootMenu now respects the `console` kernel command-line option and should behave as expected over a serial console.
* Command lists at the bottom of each menu are now sensibly wrapped to the terminal width, with extra coloring to highlight key combinations.
* Rather than rely solely on the `hostid(1)` command to populate the default hostid in the ZFSBootMenu initramfs, the dracut module will prefer to copy the `/etc/hostid` from the host, which should produce more consistent behavior on musl systems.
* Boot environments are now explicitly sorted, with the default boot environment appearing at the top of the list and selected by default.

### New features
* An online help system, accessible from `alt-h` within any menu, provides descriptions of functionality provided by ZFSBootMenu.
* The description at the top of the menu now indicates whether the selected boot environment is on a pool currently imported readonly or writable.
* New command-line arguments `zbm.lines` and `zbm.columns` allow the size of the terminal at boot time.
* When `generate-zbm` fails to parse the YAML configuration, more detailed messages pinpoint parsing errors.

### Significant commits in this release
* dbe91a1 - Fix console handling when attached to a serial line (Andrew J. Hesford)
* 9959d10 - Respect ZFS hostid behavior on musl (Andrew J. Hesford)
* f4a60e6 - Capture and print config.yaml eval failure (Zach Dykstra)
* 2ebad45 - Sort environments, fix preview (Zach Dykstra)
* cc6e27c - Control size/target of ZFSBootMenu output (Zach Dykstra)
* bb294b3 - Enable dynamic line wrapping for header (Zach Dykstra)
* 8993591 - Enable global help system (Zach Dykstra)
* 7879876 - Read-only helpers (Zach Dykstra)

## ZFSBootMenu v1.6.1 (2020-10-27)

Revert omitting `rootfs-block` by default from the ZFSBootMenu initramfs. `rootfs-block` is a hard requirement of `crypt`, which is used to setup LUKS beneath ZFS.

## ZFSBootMenu v1.6.0 (2020-10-24)

This release brings significant improvements to the pool import process. Previously, all available pools were discovered and then their health was scraped to confirm that they were in an 'ONLINE' state before importing them. This process had a few subtle shortcomings that were highlighted by the pending release of OpenZFS 2.0.0. In particular, if a zpool has been upgraded via `zpool upgrade` to enable OpenZFS 2.0.0 feature flags, but the ZFSBootMenu initramfs contains an older version of OpenZFS, the pool was not able to be automatically imported in ZFSBootMenu. The import process now relies on `zpool import -N -a -o readonly=on` to attempt to import all available and otherwise healthy pools in read-only mode. By using zpool itself to determine all of the pools that can/should be imported, ZFSBootMenu now avoids the fragile process of scraping and interpreting the human-friendly text output of `zpool import`.

### Fixes
* Improve the reliability of returning the correct kernel command line at all times. A helper function can now return corrected arguments in cases where `resume` is on the command line, but the pool has been imported read-write. This function is now used when generating a preview, making the modification more transparent to user inspection.
* Omit systemd and other modules from ZFSBootMenu by default. These install hooks that interfere with the correct operation of ZFSBootMenu.
* The testing/virtualiztion frame work has received a lot of attention during this development cycle. This has allowed us to create a variety of pool configurations that would be otherwise difficult to accomplish with physical hardware.

### New features
* When accepting user input (new filesystem name, resume protections), allow CTRL-C to be used to cancel the process.

### Significant commits in this release
* 219a632 - Rewrite pool import ahead of OpenZFS 2.0.0 (Zach Dykstra, Andrew J. Hesford)
* fb866c8 - Use zfsbootmenu-input in noresume prompt (Andrew J. Hesford)
* 1bb4f41 - Allow ctrl-c to be used during user input (Zach Dykstra)
* ca8eda8 - use -F to display the file type for more filtering options (Zach Dykstra)
* 08f22e2 - Simplify handling of BE command lines, use in previews (Andrew J. Hesford)
* cd8f889 - omit rootfs-block; it will never generate a correct KCL (Zach Dykstra)
* c96165c - Omit systemd related modules (Zach Dykstra)

## ZFSBootMenu v1.5.0 (2020-09-16)

### Fixes
* The required binaries were audited, cleaning up tools that were no longer used.
* The installation of required binaries, core scripts and other files is checked during initramfs creation. If any of these critical files can not be installed, the image is not created.
* Parameters are passed to the pool import function to control how a pool is imported. This allows for more than just readonly changes when importing.
* `config.yaml` defaults were adjusted to more closely match normal use cases. This works in tandem with the `--enable` toggle in `generate-zbm` to provide a better out-of-the-box experience.

### New features
* When importing a pool as R/W, and a resume image is found, the kernel command line is modified to remove `resume=` and to subsequently append `noresume`.
* Support `skim` in place of `fzf` for greater platform availability. `fzf` is preferred when creating an initramfs.
* The health of discovered pools can now be viewed. Optionally, a checkpoint rewind can be performed if one has been set. Use caution, this action can NOT be undone.
* Global image creation can be toggled via `generate-zbm --enable` or `generate-zbm --disable`

### Significant commits in this release
* cfec416 - Support automatic "noresume" when importing pools R/W (Andrew J. Hesford)
* a6a36bf - Add support for pool status and checkpoints (Zach Dykstra)
* 79bcca3 - Fix logic inversion in import_pool handling of $read_write (Andrew J. Hesford)
* 14b88b9 - generate-zbm: enable components in config.yaml (Andrew J. Hesford)
* 71cd075 - Add --enable/--disable (Zach Dykstra)
* 999e6c2 - Drop import_args variable and let import_pool build its own arguments (Andrew J. Hesford)
* b85d836 - support sk, an fzf workalike, for menu presentation (Zach Dykstra)
* 2225fea - module-setup.sh: catch installation failures, warn or fail as appropriate (#72) (Andrew J. Hesford)
* 5801e00 - Prune everything not explicitly needed (Zach Dykstra)


## ZFSBootMenu v1.4.1 (2020-08-19)

ZFSBootMenu 1.4.1 is a minor update, updating the provided Makefile for packagers.


## ZFSBootMenu v1.4 (2020-08-19)

ZFSBootMenu 1.4 includes significant internal changes and some user-visible functional changes in the `generate-zbm` script.

### Fixes
* Correct an issue that required two attempts to set default boot environments.
* Internal improvements to `generate-zbm` to improve consistency and facilitate future development.
* Management of versioned image retention should now be more consistent with expectation. Versioned ZBM images now increment a revision number when existing images with the same version already exist, and the retention policy preserves a configurable number of revisions for the current version alongside the latest revision of each of the same number of prior versions.
* Improved error handling should make failures in `generate-zbm` easier to understand.

### New features
* Provide man pages (generate-zbm.5, generate-zbm.8 and zfsbootmenu.7) to document the creation and use of ZFSBootMenu images.
* Move from an INI configuration format to YAML, which should provide more flexibility for future enhancements.
* Provide a `--migrate` command-line option to convert existing INI configurations to the new format.
* Add configuration options to change default behavior for `--kernel`, `--kver` and `--prefix` to make `generate-zbm` easier to incorporate on non-Void systems.
* Add a configuration option to change the default behavior for `--version` to allow customized output versioning of images.
* Support string interpolation of `%current` or `%{current}` tags in `--kver` and `--version` values.
* Add a `--cmdline` command-line option to override the configured `CommandLine` value without editing the configuration file.

### Significant commits in this release
* 0979051 - Add documentation for generate-zbm, its config and initramfs options (Zach Dykstra, et al.)
* ee1d9d8 - Unmask `import_args` in functions calling `import_pool` (Zach Dykstra)
* 3b2b2f0 - Add explicit `--migrate` option to generate-zbm (Andrew J. Hesford)
* 3cd3a8e - Improve error handling and automatic config conversion (Andrew J. Hesford)
* 80e0c30 - Switch syslinux entry to heredoc, fix syslinux.cfg file copy (Zach Dykstra)
* 6351226 - Move to YAML configuration, improve version handling (Andrew J. Hesford, Zach Dykstra)
* 5fdb872 - Add configuration options for kernel, version and prefix (Andrew J. Hesford)
* 79295ec - Add an optional parameter to safeCopy: (Zach Dykstra)
* 8aa133f - Clean up control flow in generate-zbm (Andrew J. Hesford)


## ZFSBootMenu v1.4rc1 (2020-08-11)

Except for the addition of man pages and the fix in commit ee1d9d8, the new features and fixes in this release are fully described in the final v1.4 release notes.


## ZFSBootMenu v1.3.1 (2020-07-14)

This release fixes an issue found minutes after v1.3 was tagged and released - such is life. After timing out on the countdown menu, the screen is now cleared before displaying a prompt for the pool password.

## ZFSBootMenu v1.3 (2020-07-14)

This release features several fixes and new features.

### Fixes
* When creating a boot image, `generate-zbm` will fail if the EFI System Partition (`BootMountPoint` in the configuration) is not and cannot be mounted.
* When `generate-zbm` creates backup kernels, initramfs images or UEFI bundles, timestamps of the original files will be preserved when possible, which may help boot loaders like rEFInd properly order the images.
* Some display issues in the boot menu have been fixed.

### New features
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

### Significant commits in this release
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


## ZFSBootMenu v1.3rc2 (2020-07-09)

This release contains all of the fixes and new features in v1.3rc1, as well as some fixes to command-line generation that should allow ZFSBootMenu to properly boot Arch Linux systems.


## ZFSBootMenu v1.3rc1 (2020-07-07)

The new features and fixes in this release are fully described in the final v1.3 release notes.


## ZFSBootMenu v1.2 (2020-06-22)

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


## ZFSBootMenu v1.1 (2020-06-11)

This release includes a number of small fixes and improvements.

### Fixes
* Correctly handle exiting the recovery shell, fixing an infinite loop. A reboot is no longer required to recover from the recovery shell. Thanks, @ahesford.
* Check that the EFI stub file is present on disk at the specified location. If the file is missing and an EFI bundle is requested, exit with an error.
* Minor documentation fixes.

### Features
* Handle console fonts defined on the kernel command line. This is useful for systems with a 4k display. You should now be able to read the screen without a magnifying glass. Thanks to @ahesford for the significant time spent on tracking this down.
* Instead of calling `objcopy` directly, `dracut` is now used to generate a bundled EFI file. This means that the bundled EFI file can now be signed by Secure Boot keys! Thanks to @ericonr for this feature - and learning a bit of Perl to do it!

No configuration file changes are needed to use this release. Enjoy!


## ZFSBootMenu v1.0 (2020-05-15)

We're jumping straight up to v1.0!

### Small changes
* Set the kernel log level to 0 when in the menu system, then restore it to the original value on boot
* Reverse sort the kernel list, so the most recent is always first
* Add an initial chroot helper script, `zfs-chroot` for the recovery shell. It can be invoked as `zfs-chroot pool/ROOT/BE`.
* Set the default config path in `generate-zbm` to `/etc/zfsbootmenu/conf.d`
* Allow the EFI stub file to be defined in config.ini
* Optionally read the kernel command line from `/etc/default/zfsbootmenu`

### Large changes
* Clean up or whitelist all issues in `zfsbootmenu-lib.sh`, `zfsbootmenu-preview.sh` and `zfsbootmenu.sh` noted by shellcheck.
* Support entering a custom kernel command line via `alt-c` on the main menu. The input line is pre-filled with the command line that would have been used on the next boot, for that environment. This command line is NOT persisted between reboots, it's simply here to let you recover an unbootable system.
* Add support for reading the kernel commandline from the ZFS property `org.zfsbootmenu:commandline`.  This property is now considered the default/primary source of truth for the kernel command line - it takes precedence over `/etc/default/zfsbootmenu` and `/etc/default/grub`.

A big thank you to @ahesford for his code contributions and testing leading up to this release!


## ZFSBootMenu v1.0rc2 (2020-05-12)

This release contains all of the fixes and features from 1.0rc1, as well as the following:

* Add support for reading the kernel commandline from the ZFS property `org.zfsbootmenu:commandline`. This property takes precedence over `/etc/default/grub` and `/etc/default/zfsbootmenu`
* Clean up or whitelist all issues in `zfsbootmenu-lib.sh`, `zfsbootmenu-preview.sh` and `zfsbootmenu.sh` noted by shellcheck.

A big thank you to @ahesford for his code contributions and testing leading up to this release candidate. It is very much appreciated!


## ZFSBootMenu 1.0rc1 (2020-05-11)

This release has been a long time coming. In no particular order, it contains the following:

* Set the kernel log level to 0 when in the menu system, then restore it to the original value on boot
* Reverse sort the kernel list, so the most recent is always first
* Add an initial chroot helper script for the recovery shell
* Set the default config path in `generate-zbm` to `/etc/zfsbootmenu/conf.d`
* Allow the EFI stub file to be defined in config.ini
* Support entering a custom kernel command line via `alt-c` on the main menu. The input line is pre-filled with the command line that would have been used on the next boot, for that environment. This command line is NOT persisted between reboots, it's simply here to let you recover an unbootable system.


## ZFSBootMenu 0.8.1 (2020-01-19)

This release adds a few improvements to generate-zbm.

* When finding kernels in /boot to use as the base for zfsbootmenu, the list is properly sorted so something like 5.4.11 is now a higher version than 5.3.18.
* Output files now have `_1` appended to them (both kernel and initramfs) to workaround a gotcha with Petitboots' syslinux.cfg parser ignoring files ending in `.0`.
* If the bootloader partition is defined in config.ini, generate-zbm will now mount it and unmount it for you. If it's already mounted, it's left alone.
* Syslinux mode now builds off of [Components] mode, instead of adding yet another code path for generating the initramfs. This makes syslinux mode simply a syslinux.cfg renderer.


## ZFSBootMenu 0.8.0 (2020-01-12)

This release adds a preview function to the primary menu screen. Two lines are shown at the top of the display.

Line 1: Selected boot environment (if it's the bootfs) - and the default kernel
Line 2: The discovered kernel arguments for the kernel in that boot environment

Additional features added in include:

* Set bootfs for a pool via `alt+d` on the main menu screen
* Ability to clone the same snapshot up to 1000 times. After cloning a snapshot, it can be set as the bootfs in the menu.
* Reduce the helper text to one line on all screens, to make it not as visually cluttered
* Finding kernel arguments has now been moved to a function, which can be extended to support multiple OS's as the need arises


## ZFSBootMenu 0.7.7 (2020-01-08)

This release adds support for generating a syslinux/extlinux-compatible configuration file. This can be used both with Petitboot on POWER hardware and with extlinux on x86_64.


## ZFSBootMenu 0.7.6 (2019-12-31)

This is a fairly minor release, with the removal of an external VERSION file and the inclusion of a basic Makefile being the major impacting changes.


## ZFSBootMenu 0.7.5 (2019-12-24)

A previous release defaulted pool imports to read-only mode. Because of this, cloning a snapshot would fail. This release fixes that by detecting if a pool is imported as read-only, exporting it and re-importing it read-write. If the snapshot being cloned is encrypted, keys will be loaded again (from file or via prompt).

To control read-write behavior, the command line argument `read_write` has been added. If unset, this option defaults to 0, importing the pool in read-only mode. Set to 1 to enable read-write on imported pools by default.


## ZFSBootMenu 0.7.4.1 (2019-12-20)

Point release to fix issues on a fresh installation with missing target paths.


## ZFSBootMenu 0.7.4 (2019-12-20)

This release fixes a glaring integration issue with rEFInd. Unified EFI files now use the platform kernel base (vmlinux, vmlinuz, etc), with the version and EFI appended. This allows them to integrate nicely with rEFInd's boot options and kernel roll-up features.


## ZFSBootMenu 0.7.3 (2019-12-20)

This release adds the helper bin/generate-zbm which can help control the lifecycle of a the components needed to boot a system. It can generate a versioned kernel and initramfs, and/or a combined kernel/initramfs/commandline EFI executable. The helper script is able to able to do un-versioned files as well, creating initramfs-zfsbootmenu.img and then rotating that into initramfs-zfsbootmenu-backup.img when a new initramfs is created.

To better integrate with boot loaders like rEFInd, the option 'timeout' can be set on the command line when booting into the bootmenu.

A value of 0 will bypass the countdown timer and menu screens, attempting to boot the environment set by bootfs.
A value of -1 will force you into the menu system, where you can pick a boot environment, kernel, snapshot etc.
Any positive integer value will enable the countdown timer, where the system will then attempt to boot the environment set by bootfs.

The default timeout value remains at 10 seconds, consistent with previous behavior.


## ZFSBootMenu 0.7.2 (2019-12-10)

Default the creation of the initramfs to hostonly mode, to substantially reduce the size of the generated file.


## ZFSBootMenu 0.7.1 (2019-12-10)

Minor bug fix release. Correctly handle a zpool value on the command line pointing to a non-existent pool. Additionally, when trying to read a pinned kernel version, read it from the selected BE, and not the BE pointed to by `bootfs`


## ZFSBootMenu 0.7.0 (2019-12-09)

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


## ZFSBootMenu 0.6.5 (2019-11-16)

This is largely a bug-fix release, built on top of Linux 5.3.10 and ZFS 0.8.2 for x86_64 and ppc64le (POWER8+).

* Properly sort the list of kernels by version, so that 5.x.10 is
considered a higher version than 5.x.9
*  Correctly set a return value for all zfs load-key operations
* Greatly simplify when a BE is mounted when trying to find kernels in
/boot
* Only add a BE to the environment list if one or more kernel/initramfs
pairs were found


## ZFSBootMenu 0.6 (2019-11-06)

This release brings support for native ZoL encryption! It supports encryption on the entire pool, or enabled for a specific boot environment!

Prompting for the passphrase happens if the key needs to be loaded to boot the environment set in `bootfs` or if you escape the auto-boot screen to enter the environment/snapshot/kernel browser.

A patch is provided for 90zfs/mount-zfs.sh which detects if the keylocation is a file, and then attempts to load it from disk. If the key file is not present, and the type is passphrase, it will prompt.

The default auto-boot screen now attempts to center itself in your tty, for a slightly easier to read output.

Booting from a snapshot has been fixed - the snapshot is now correctly unmounted after a kernel/initramfs pair is located in /boot from the snapshot.


## ZFSBootMenu 0.5 (2019-10-22)

Initial release!

The dracut module has been built into an initramfs for both x86_64 and ppc64le (POWER8+) - with Linux 5.3.7. A sample grub.cfg is provided, demonstrating how to enter the boot menu. Update your pool name, and set spl_hostid based on the output of 'hostid' on your machine.

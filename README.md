# Introduction

[![Build check](https://github.com/zbm-dev/zfsbootmenu/actions/workflows/build.yml/badge.svg?branch=master)](https://github.com/zbm-dev/zfsbootmenu/actions/workflows/build.yml) [![latest packaged version(s)](https://repology.org/badge/latest-versions/zfsbootmenu.svg)](https://repology.org/project/zfsbootmenu/versions)

ZFSBootMenu is a Linux bootloader that attempts to provide an experience similar to FreeBSD's bootloader. By taking advantage of ZFS features, it allows a user to have multiple "boot environments" (with different distros, for example), manipulate snapshots before booting, and, for the adventurous user, even bootstrap a system installation via `zfs recv`.

In essence, ZFSBootMenu is a small, self-contained Linux system that knows how to find other Linux kernels and initramfs images within ZFS filesystems. When a suitable kernel and initramfs are identified (either through an automatic process or direct user selection), ZFSBootMenu launches that kernel using the `kexec` command.

![screenshot](/media/v1.11.0-multi-be.png?raw=true)

In broad strokes, it works as follows:

* Via direct EFI booting, an EFI boot manager like refind, `rEFInd`, a BIOS bootloader like `syslinux`, or some other means, boot ZFSBootMenu (as either a self-contained UEFI application or a dedicated Linux kernel and initramfs image).
* Find all healthy ZFS pools and import them.
* If appropriate, select a preferred boot environment:
    * If the ZFSBootMenu command line specifies no pool preference, prefer the filesystem indicated by the `bootfs` property (if defined) on the first-found pool.
    * If the ZFSBootMenu command line specifies a pool preference, and that pool has been imported, prefer the filesystem indicated by its `bootfs` property (if defined).
    * If a `bootfs` value has been identified, start an interruptable countdown (by default, 10 seconds) to automatically boot that environment.
    * If no `bootfs` value can be identified or the automatic countdown was interrupted, search all imported pools for filesystems that set `mountpoint=/` and contain a `/boot` subdirectory that contains Linux kernels and initramfs images. Present a list of identified environments for user selection via `fzf`.
* Mount the filesystem representing the selected boot environment and find the highest versioned kernel in `/boot` in the selected boot environment.
* Using `kexec`, load the selected kernel and initramfs into memory, setting the kernel command line with the contents of the `org.zfsbootmenu:commandline` property for that filesystem.
* Unmount all ZFS filesystems.
* Boot the final kernel and initramfs.

At this point, you'll be booting into your usual OS-managed kernel and initramfs, along with any arguments needed to correctly boot your system.

Whenever ZFSBootMenu encounters natively encrypted ZFS filesystems that it intends to scan for boot environments, it will prompt the user to enter a passphrase as necessary.

This tool makes uses of the following additional software:
 * [fzf](https://github.com/junegunn/fzf)
 * [kexec-tools](https://github.com/horms/kexec-tools)
 * [mbuffer](http://www.maier-komor.de/mbuffer.html)
 * [Linux Kernel](https://www.kernel.org)
 * [ZFS on Linux](https://zfsonlinux.org)

The ZFSBootMenu image is created from your regular system utilities using an initramfs generator. Image creation is known to work and explicitly supported with:

 * [dracut](https://github.com/dracutdevs/dracut), and
 * [mkinitcpio](https://github.com/archlinux/mkinitcpio)

Note that ZFSBootMenu does *not* replace your regular initramfs image. In fact, it is possible to use one of the supported generators to produce a ZFSBootMenu image even on Linux distributions entirely different program to produce their initramfs images (*e.g.*, `initramfs-tools` on Debian or Ubuntu).

ZFSBootMenu is capable of booting just about any Linux distribution. Major distributions that are known to boot without requiring any special configuration include:

* Void
* Arch
* Alpine
* Gentoo
* Debian and its descendants (Ubuntu, Linux Mint, Devuan, etc.)

Red Hat and its descendants (RHEL, CentOS, Fedora, etc.) are expected to work as well but have never been tested. ZFSBootMenu also provides several configuration options that can be used to fine-tune the boot process for nonstandard configurations.

Each release includes pre-generated images (both a monolithic UEFI applications as well as separate kernel and initramfs components suitable for both UEFI and BIOS systems) based on Void Linux. Building a custom image is known to work in the following configurations:

* With `mkinitcpio` or `dracut` on Void (the `zfsbootmenu` package will make sure all prerequisites are available)
* With `mkinitcpio` or `dracut` on Arch
* With `dracut` on Debian or Ubuntu (installed as `dracut-core` to avoid replacing the system `initramfs-tools` setup)

If you run Docker or [podman](https://podman.io/), it is also possible to build custom ZFSBootMenu images in a container. The [zbm-builder.sh](zbm-builder.sh) script provides a simpler wrapper that will use your own configuration in the current directory to produce custom images.

# ZFS boot environments

From the perspective of ZFSBootMenu, a "boot environment" is simply a ZFS filesystem that contains a Linux kernel and initramfs in its `/boot` subdirectory. More thorough consideration of the concept is presented in the [boot environment primer](BOOTENVS.md).

# System prereqs

To ensure the boot menu can find your kernels, you'll need to ensure `/boot` resides on your ZFS filesystem. An example filesystem layout is as follows:

```
NAME                           USED  AVAIL     REFER  MOUNTPOINT
zroot                          278G   582G       96K  none
zroot/ROOT                    10.9G   582G       96K  none
zroot/ROOT/void.2019.10.04    1.20M   582G     7.17G  /
zroot/ROOT/void.2019.11.01    10.9G   582G     7.17G  /
zroot/home                     120G   582G     11.8G  /home
```

There are two boot environments created, identified by mounting to /.  The environment that this system will boot into is defined by the `bootfs` value set on the `zroot` zpool.

```
NAME   PROPERTY  VALUE                       SOURCE
zroot  bootfs    zroot/ROOT/void.2019.11.01  local
```

On start, ZFSBootMenu will find the highest versioned kernel in `zroot/ROOT/void.2019.11.01/boot`, confirm that a matching initramfs is present, and default to booting the OS with that.

# Installation

Kernel command-line (KCL) arguments should be configured by setting the `org.zfsbootmenu:commandline` ZFS property for each boot environment.  Do not set any `root=` or any other pool-related options in the kernel command line; these will be filled in automatically when a boot environment is selected.

Because ZFS properties are inherited by default, it is possible to set the `org.zfsbootmenu:commandline` property on a common parent to apply the same KCL arguments to multiple environments. Setting the property locally on individual boot environments will override the common defaults.

As a special accommodation, the substitution keyword `%{parent}` in the KCL property will be recursively expanded to whatever the value of `org.zfsbootmenu:commandline` would be on the parent dataset. This allows, for example, mixing options common to multiple environments with those specific to each:

```sh
zfs set org.zfsbootmenu:commandline="zfs.zfs_arc_max=8589934592 elevator=noop" zroot/ROOT
zfs set org.zfsbootmenu:commandline="%{parent} loglevel=4" zroot/ROOT/void.2019.11.01
zfs set org.zfsbootmenu:commandline="loglevel=7 %{parent}" zroot/ROOT/void.2019.10.04
```

will cause ZFSBootMenu to interpret the KCL for `zroot/ROOT/void.2019.11.01` as

```
zfs.zfs_arc_max=8589934592 elevator=noop loglevel=4
```

while the KCL for `zroot/ROOT/void.2019.10.04` would be

```
loglevel=7 zfs.zfs_arc_max=8589934592 elevator=noop
```


## EFI

ZFSBootMenu integrates nicely with an EFI system. There will be two key things to configure here.

* The mountpoint of the EFI partition and its contents.
* The mountpoint of the boot environment `/boot` and its contents.

Each boot environment should have its `/boot` directory in the ZFS filesystem. Using the above example, `zroot/ROOT/void.2019.11.01` would contain `/boot` with kernel/initramfs pairs:

```
# ls /boot
config-5.3.18_1
config-5.4.6_1
efi
initramfs-5.3.18_1.img
initramfs-5.4.6_1.img
System.map-5.3.18_1
System.map-5.4.6_1
vmlinuz-5.3.18_1
vmlinuz-5.4.6_1
```

Once `/boot` is contained in a boot environment, it is necessary to install the boot menu files. Typically, EFI partitions (ESP) are mounted to `/boot/efi`, and contain a number of sub-directories. In this example, `/boot/efi/EFI/void` holds the ZFSBootMenu kernel and initramfs.

```
# lsblk -f /dev/sda
NAME   FSTYPE LABEL UUID                                 FSAVAIL FSUSE% MOUNTPOINT
sdg
├─sda1 vfat         AFC2-35EE                               7.9G     1% /boot/efi
└─sda2 swap         412401b6-4aec-4452-a6bd-6fc20fbdc2a5                [SWAP]

# ls /boot/efi/EFI/void/
initramfs-0.7.4.img
initramfs-0.7.5.img
vmlinuz-0.7.4
vmlinuz-0.7.5
```

With this layout, you'll now need a way to boot the kernel and initramfs via EFI. This can be done via a manual entry set via [efibootmgr](https://github.com/rhboot/efibootmgr), or it can be done with [rEFInd](http://www.rodsbooks.com/refind/).

If you do not generate the ZFSBootMenu initramfs locally, you'll need to identify the following additional details:

* Your system's hostid (`hostid`). It's important that this command be executed as root, to ensure that it returns the correct value.
* Your boot pool name, if you have multiple.
* The disk path and partition index of your EFI partition. (`/dev/sda`, part 1)

### efibootmgr

```
efibootmgr --disk /dev/sda \
  --part 1 \
  --create \
  --label "ZFSBootMenu" \
  --loader /vmlinuz-0.7.5 \
  --unicode 'root=zfsbootmenu:POOL=zroot ro initrd=\EFI\void\initramfs-0.7.5.img quiet spl_hostid=a8c0a2a8' \
  --verbose
```

Take note to adjust `root=zfsbootmenu:POOL=`, `spl_hostid=`, `--disk` and `--part` to match your system configuration.

Each time ZFSBootMenu is updated, a new EFI entry will need to be manually added, unless you disable versioning in the ZFSBootMenu configuration.

### rEFInd

`rEFInd` is considerably easier to install and manage. Refer to your distribution's packages for installation. Once rEFInd has been installed, you can create `refind_linux.conf` in the directory holding the ZFSBootMenu files (`/boot/efi/EFI/void` in our example):

```
"Boot Default BE" "ro quiet loglevel=0 timeout=0 root=zfsbootmenu:POOL= spl_hostid="
"Select BE" "ro quiet loglevel=0 timeout=-1 root=zfsbootmenu:POOL= spl_hostid="
```

As with the efibootmgr section, the `root=zfsbootmenu:POOL=` and `spl_hostid=` options need to be configured to match your environment.

This file will configure `rEFInd` to create two entries for each kernel and initramfs pair it finds. The first will directly boot into the environment set via the `bootfs` pool property. The second will force ZFSBootMenu to display an environment / kernel / snapshot selection menu, allowing you to boot alternate environments, kernels and snapshots.

# Kernel command line options

The [zfsbootmenu(7)](pod/zfsbootmenu.7.pod#cli-parameters) manual page describes command line options for ZFSBootMenu kernels in detail.

# ZFS properties

The [zfsbootmenu(7)](pod/zfsbootmenu.7.pod#zfs-properties) manual page describes ZFS properties interpreted by ZFSBootMenu.

# initramfs creation

`bin/generate-zbm` can be used to create an initramfs on your system. It ships with Void-specific defaults in [etc/zfsbootmenu/config.yaml](etc/zfsbootmenu/config.yaml). To create an initramfs, the following additional tools/libraries will need to be available on your system:

 * For inclusion in the initramfs:
   * [fzf](https://github.com/junegunn/fzf)
   * [kexec-tools](https://github.com/horms/kexec-tools)
   * [mbuffer](http://www.maier-komor.de/mbuffer.html)
 * For running `bin/generate-zbm`:
   * [perl Sort::Versions](https://metacpan.org/pod/Sort::Versions)
   * [perl Config::IniFiles](https://metacpan.org/pod/Config::IniFiles)
   * [perl YAML::PP](https://metacpan.org/pod/YAML::PP)
   * [perl boolean](https://metacpan.org/pod/boolean)

If you want to create a unified EFI executable (which bundles the kernel, initramfs and command line), you will also need:

 * linuxx64.efi.stub (typically packaged with gummiboot or systemd-boot)

Your distribution should have packages for these already.

## config.yaml

[config.yaml](pod/generate-zbm.5.pod) is used to control the operation of [generate-zbm](bin/generate-zbm).

## Conversion of legacy configurations

In prior versions of ZFSBootMenu, an INI format was used for configuration. In general, migration to the new format is not automatic, but `generate-zbm` can perform the migration if your distribution package has not done it for you. To migrate an existing configuration, just run

```
generate-zbm --migrate [ini-config] [--config yaml-config]
```

By default, the output YAML will be written to `/etc/zfsbootmenu/config.yaml`; use the `--config` argument to customize the output location.

The argument `[ini-config]` to `--migrate` is optional. When it is not provided, `generate-zbm` will derive an input file by replacing the `.yaml` extension from the output file with a `.ini` extension.

If (and only if) `generate-zbm` is run without a `--config` option (*i.e.*, it attempts to load the default `/etc/zfsbootmenu/config.yaml`) and the default configuration does *not* exist, `generate-zbm` will behave as if it had been passed the `--migrate /etc/zfsbootmenu/config.ini` option.

Whenever `generate-zbm` attempts to migrate configuration files, it will exit with a zero exit code on successful conversion and a nonzero exit code if problems were encountered during the conversion. No boot images will be produced in the same invocation as a migration attempt.

## Dealing with driver conflicts

For some combination of hardware and kernel modules, the ZFSBootMenu kernel may leave hardware in an unexpected state and prevent the boot environment from properly initializing and attaching drivers. The simplest way to avoid this issue is to disable the affected kernel modules in ZFSBootMenu, leaving all hardware initialization to the final kernel. For example, if Nvidia graphics hardware does not function as expected, a dracut configuration file can be added to `/etc/zfsbootmenu/dracut.conf.d` to exclude the `nouveau` and `nvidia` drivers from ZFSBootMenu. Adding the line

```
omit_drivers+=" nouveau nvidia "
```

to a file called, *e.g.*, `/etc/zfsbootmenu/dracut.conf.d/nvidia.conf` should restore expected functionality to your boot environment after recreating your ZFSBootMenu image with `generate-zbm`.

In other cases, it is not possible to exclude drivers without depriving ZFSBootMenu of critical hardware support. For example, some XHCI USB controllers may not be properly initialized after a `kexec`, leaving a boot environment without USB devices like a keyboard. However, excluding XHCI drivers from ZFSBootMenu would make the same keyboard inoperable in the boot menu, making it impossible to interact with the menus. ZFSBootMenu provides "teardown hooks" that can sometimes be used to address these situations. Teardown hooks are invoked immediately before a target kernel is booted via `kexec` and provide an opportunity to run last-minute commands to prepare the system for the boot. Scripts may be registered as teardown hooks by adding text of the form

```
zfsbootmenu_teardown+=" <path to script> "
```

where `<path to script>` points to an **executable** script or program. A sample [XHCI teardown script](contrib/xhci-teardown.sh) demonstrates the use of teardown hooks to unbind the XHCI driver from the USB controllers in the ZFSBootMenu kernel before launching the selected boot environment, allowing the next kernel to properly initialize the controller.

# Native encryption

ZFSBootMenu can import pools or filesystems with native encryption enabled. If your boot environments are not encrypted but, for example, `/home` is, you will not receive a decryption prompt during boot. To ensure that you can decrypt your pool to load the kernel and initramfs, you'll need to you have the filesystem parameters configured correctly.

```
zfs get all zroot | egrep '(encryption|keylocation|keyformat)'
zroot  encryption            aes-256-gcm                -
zroot  keylocation           file:///etc/zfs/zroot.key  local
zroot  keyformat             passphrase                 -
zroot  encryptionroot        zroot                      -
```

It's critical that `keyformat` is set to `passphrase`, otherwise you'll be unable to enter the correct value in the boot loader. ZFS on Linux currently supports only one key, but in a way which we can exploit: if you configure the `keylocation` value to a file on disk, put your passphrase in that, and then include that file into the FINAL initramfs (the OS-managed one), you won't receive a second password prompt on boot. You'll still receive a password prompt in the boot loader, since we can force a prompt for passphrase input.

For Dracut-based systems, this can be done by creating a `/etc/dracut.conf.d/zol.conf` file with the following contents:

```
install_items+=" /etc/zfs/zroot.key "
```

It's critical that you do not include this key file into the ZFSBootMenu initramfs, since that file exists on an unencrypted volume - leaving your pool essentially wide-open.

For convenience, ZFSBootMenu recognizes the ZFS property `org.zfsbootmenu:keysource` as the name of a filesystem that should be searched for ZFS key files. When a boot environment specifies a `file://` URI as its `keylocation`, ZFSBootMenu will attempt to mount a filesystem indicated by the `org.zfsbootmenu:keysource` property (if it exists) and search for the named `keylocation` therein. If found, ZFSBootMenu will copy the key into a cache within the in-memory root filesystem so that subsequent operations that require reloading the key (for example, changing the default boot environment or cloning a snapshot) will not prompt the user for passphrases.

When searching for a `keylocation` relative to the filesystem named by `org.zfsbootmenu:keysource`, ZFSBootMenu will first try to strip the `mountpoint` of the keysource filesystem from any `keylocation` URI that references the keys to map the `keylocation` that would be observed on a running system to the proper location in the keysource. For example, if the running system is set up so that `zroot` is the `encryptionroot` for all filesystems on a pool, running the commands

```sh
zfs create -o mountpoint=/etc/zfs/keys zroot/keystore
echo "MySecretPassphrase" > /etc/zfs/keys/zroot.key
chmod 000 /etc/zfs/keys/zroot.key
zfs set keylocation=file:///etc/zfs/keys/zroot.key zroot
zfs set org.zfsbootmenu:keysource=zroot/keystore zroot
echo install_optional_items+=" /etc/zfs/keys/zroot.key " >> /etc/dracut.conf.d/zol.conf
```

will cause ZFSBootMenu to attempt to cache the key `file:///etc/zfs/keys/zroot.key` from `zroot/keystore` when unlocking the `zroot` pool. Because `zroot/keystore` specifies `mountpoint=/etc/zfs/keys`, ZFSBootMenu will first try to strip `/etc/zfs/keys` from the `keylocation` URI, looking for the file `zroot.key` at the root of the filesystem `zroot/keystore`. If this fails, ZFSBootMenu will fall back to the full path, looking for `etc/zfs/keys/zroot.key` within the keysource filesystem. If either location is found, ZFSBootMenu will retain a cache of the key should it be needed to unlock the pool again.

# Signature Verification and Prebuilt EFI Executables

ZFSBootMenu is now distributed as a prebuilt EFI executable alongside the source releases. For many systems, it is sufficient to drop the EFI executable on an EFI System Partition and configure your firmware to boot the file.

Each EFI executable we release is signed with [`signify`](https://flak.tedunangst.com/post/signify), which provides a simple method for verifying that the contents of the file are as this project intended. Once you've installed `signify` (that's left as an exercise, although Void Linux provides the `signify` package for this purpose), just download the EFI bundle from the [releases page](https://github.com/zbm-dev/zfsbootmenu/releases), download the `sha256.sig` file alongside it, and run

```
signify -C -x sha256.sig
```

You will also need the public key used to sign ZFSBootMenu executables. The key is available at [releng/keys/zfsbootmenu.pub](https://github.com/zbm-dev/zfsbootmenu/blob/master/releng/keys/zfsbootmenu.pub). Install this file as `/etc/signify/zfsbootmenu.pub` if you like; this key can be used for all subsequent verifications. Otherwise, look at the `-p` command-line option for `signify` to provide a path to the key.

The signature file `sha256.sig` also includes a signature for the source tarball corresponding to the release. If this file is not present alongside the EFI bundle and the signature file, `signify` will complain about its signature. This error message is OK to ignore; alternatively, tell `signify` to verify only the EFI bundle, or download the source tarball alongside the other files.

The signify key `zfsbootmenu.pub` may be verified; alongside the public key is [releng/keys/zfsbootmenu.pub.gpg](https://github.com/zbm-dev/zfsbootmenu/blob/master/releng/keys/zfsbootmenu.pub.gpg), a GnuPG signature produced with a personal key from [@ahesford](http://keys.gnupg.net/pks/lookup?op=vindex&fingerprint=on&search=0x312485BE75E3D7AC), one of the members of the ZFSBootMenu project. To verify the `signify` key, download the key `zfsbootmenu.pub` and its signature file `zfsbootmenu.pub.gpg`, then run

```
gpg2 --recv-key 0x312485BE75E3D7AC
gpg2 --verify zfsbootmenu.pub.gpg
```

NOTE: on some distributions, `gpg2` may instead by `gpg`.

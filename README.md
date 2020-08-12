# Introduction

![](https://github.com/zdykstra/zfsbootmenu/workflows/ZFS%20Boot%20Menu/badge.svg)

[![asciicast](https://asciinema.org/a/FN4gWtVUPPXzgZPrCjd8mK6Vz.svg)](https://asciinema.org/a/FN4gWtVUPPXzgZPrCjd8mK6Vz)

zfsbootmenu is implemented as a Dracut module to provide an experience similar to FreeBSD's bootloader, for Linux distributions. In broad strokes, it works as follows:

* Via GRUB, direct EFI booting, etc, boot a Linux kernel along with an initramfs containing ZFSBootMenu
* Look for `zfsbootmenu` on the kernel command line
    * Optionally specify a default pool (if multiple are present)
* Find all healthy pools and then import them
* If a specific pool was set, look for the bootfs pool value. Prefer this boot environment.
    * If no pool was defined on the command line, use the bootfs value on the first-found pool
    * If a bootfs value is defined, start a 10 second countdown to boot that environment with the highest kernel found in /boot
    * If no bootfs value is defined, find every filesystem that mounts to / with a /boot directory, and find every kernel. Prompt via fzf.
        * If needed, prompt for encryption passphrases
* Once the count down has been reached for the bootfs-selected environment, prompt for the encryption passphrase if needed
* Mount the filesystem and find the highest-numbered kernel in /boot in the boot environment.
* Load the kernel, initramfs and the kernel command line defined in the `org.zfsbootmenu:commandline` property (or, as a fallback, `/etc/default/grub`) into memory via kexec
* Unmount all ZFS filesystems
* Boot the final kernel and initramfs

At this point, you'll be booting into your OS-managed kernel and initramfs, along with any arguments needed to correctly boot your system.

This tool makes uses of the following additional software:
 * [fzf](https://github.com/junegunn/fzf)
 * [kexec-tools](https://github.com/horms/kexec-tools)
 * [mbuffer](http://www.maier-komor.de/mbuffer.html)
 * [Linux Kernel](https://www.kernel.org)
 * [ZFS on Linux](https://zfsonlinux.org)
 * [dracut](https://github.com/dracutdevs/dracut)

 ZFSBootMenu has been tested successfully with Kernel 5.7.13, Dracut 050 and ZFS On Linux 0.8.4.

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

Kernel command-line arguments should be set by setting the ZFS property `org.zfsbootmenu:commandline` on each boot environment. If the property is not defined for a boot environment or its parents, command-line arguments will be taken from the `GRUB_CMDLINE_LINUX_DEFAULT` variable in the file `/etc/default/grub` of the boot environment if the file exist and the variable is defined. Do not set any `root=` or any other pool-related options in the kernel command line; these will be filled in automatically when a boot environment is selected.

For example, I have the following command-line arguments set on my boot environment:

```
zfs.zfs_arc_max=8589934592 elevator=noop
```

Because ZFS properties are inherited by default, it is possible to set the `org.zfsbootmenu:commandline` property on a common parent to apply the same arguments to multiple environments. Setting the property locally on individual boot environments will override the common defaults.

## EFI

ZFSBootMenu integrates nicely with an EFI system. There will be two key things to configure here.

* The mountpoint of the EFI partition and it's contents
* The mountpoint of the boot environment `/boot` and it's contents

Each boot environment should have `/boot` live on the ZFS filesystem. Using the above example, `zroot/ROOT/void.2019.11.01` would contain `/boot` with any kernel/initramfs pairs.

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


Once `/boot` is backed by ZFS in a boot environment, you'll need to install the boot menu files. Typically, EFI partitions are mounted to `/boot/efi`, and contain a number of sub-directories. In this example, `/boot/efi/EFI/void` holds the ZFSBootMenu kernel and initramfs.

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


With this layout, you'll now need a way to boot the kernel and initramfs via EFI. This can be done via a manual entry set via efibootmgr, or it can be done with rEFInd.

If you are using a pre-built kernel and initramfs downloaded from the releases page, you'll need to identify the following additional details:

* Your system's hostid (`hostid`). It's important that this command is executed as root, to ensure that it returns the correct value.
* Your boot pool name, if you have multiple.
* The disk path and partition index of your EFI partition. (/dev/sda, part 1)

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

Take note to adjust `zfsbootmenu:POOL=`, `spl_hostid=`, `--disk` and `--part` to match your system configuration.

Each time the bootmenu is updated, a new EFI entry will need to be manually added.

### rEFInd

`rEFInd` is considerably easier to install and manage. Refer to your distributions packages for installation. Once rEFInd has been installed, you can create `refind_linux.conf` in the directory holding the ZFSBootMenu files (`/boot/efi/EFI/void` in our example):

```
"Boot Default BE" "ro quiet loglevel=0 timeout=0 zfsbootmenu:POOL= spl_hostid="
"Select BE" "ro quiet loglevel=0 timeout=-1 zfsbootmenu:POOL= spl_hostid="
```


As with the efibootmgr section, the `zfsbootmenu:POOL=` and `spl_hostid=` options need to be configured to match your environment.

This file will configure `rEFInd` to create two entries for each kernel and initrams pair it finds. The first will directly boot into the environment set via the `bootfs` pool property. The second will force ZFSBootMenu to display an environment / kernel / snapshot selection menu, allowing you to boot alternate environments, kernels and snapshots.

# Kernel command-line options

The [zfsbootmenu(7)](pod/zfsbootmenu.7.pod#cli-parameters) manual page describes command-line options for ZFSBootMenu kernels in detail.

# ZFS properties

The [zfsbootmenu(7)](pod/zfsbootmenu.7.pod#zfs-properties) manual page describes ZFS properties interpreted by ZFSBootMenu.

# initramfs creation

`bin/generate-zbm` can be used to create an initramfs on your system. It ships with void-specific defaults in [etc/zfsbootmenu/config.yaml](etc/zfsbootmenu/config.yaml). To create an initramfs, the following additional tools/libraries will need to be available on your system:

 * [fzf](https://github.com/junegunn/fzf)
 * [kexec-tools](https://github.com/horms/kexec-tools)
 * [mbuffer](http://www.maier-komor.de/mbuffer.html)
 * [perl Config::IniFiles](https://metacpan.org/pod/Config::IniFiles)
 * [perl YAML::PP](https://metacpan.org/pod/YAML::PP)

If you want to create an unified EFI file (kernel, initramfs, command line), you will also need:

* linuxx64.efi.stub (typically packaged with gummiboot)

Your distribution should have packages for these already.

## config.yaml

[config.yaml](pod/generate-zbm.5.pod) is used to control the operation of [generate-zbm](bin/generate-zbm). 

## Conversion of legacy configurations

In prior versions of ZFSBootMenu, an INI format was used for configuration. In general, migration to the new format is not automatic, but `generate-zbm` can perform the migration if your distribution package has not done it for you. To migrate an existing configuration, just run

```
generate-zbm --migrate [ini-config] [--config yaml-config]
```

By default, the output YAML will be written to `/etc/zfsbootmenu/config.yaml`; use the `--config` argument to customize the output location.

The argument `[ini-config]` to `--migrate` is optional. When it is not provided, `generate-zbm` will derive an input file by dropping the `.yaml` extension from the output file and appending a `.ini` extension.

If (and only if) `generate-zbm` is run without a `--config` option (*i.e.*, it attempts to load the default `/etc/zfsbootmenu/config.yaml`) and the default configuration does *not* exist. Under these circumstances, `generate-zbm` will behave as if it were passed the `--migrate /etc/zfsbootmenu/config.ini` option.

Whenever `generate-zbm` attempts to migrate configuraton files, it will exit immediately with a zero exit code on successful conversion and a nonzero exit code if problems were encountered during the conversion. No boot images will be produced in the same invocation as a migration attempt.

# Native encryption

ZFSBootMenu can import pools or filesystems with native encryption enabled. If your boot environments are not encrypted but say /home is, you will not receive a decryption prompt. To ensure that you can decrypt your pool to load the kernel and initramfs, you'll need to you have the filesystem parameters configured correctly.

```
zfs get all zroot | egrep '(encryption|keylocation|keyformat)'
zroot  encryption            aes-256-gcm                -
zroot  keylocation           file:///etc/zfs/zroot.key  local
zroot  keyformat             passphrase                 -
zroot  encryptionroot        zroot                      -
```
It's critical that `keyformat` is set to `passphrase`, otherwise you'll be unable to enter the correct value in the boot loader. ZoL currently only supports one key, but it does have a behavior that we can exploit. If you configure the `keylocation` value to a file on disk, put your passphrase in that, and then put that file into the FINAL initramfs, you won't receive a second password prompt on boot. You'll then still receive a password prompt in the boot loader, since we can force a prompt for passphrase input.

For Dracut-based systems, this can be done by creating `/etc/dracut.conf.d/zol.conf` with the following contents:

```
install_items+=" /etc/zfs/zroot.key "
```

It's critical that you do not put this key file into the ZFSBootMenu initramfs, since that file exists on an unencrypted volume - leaving your pool essentially wide-open.

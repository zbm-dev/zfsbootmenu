# Introduction

![](https://github.com/zdykstra/zfsbootmenu/workflows/ZFS%20Boot%20Menu/badge.svg)

[![asciicast](https://asciinema.org/a/FN4gWtVUPPXzgZPrCjd8mK6Vz.svg)](https://asciinema.org/a/FN4gWtVUPPXzgZPrCjd8mK6Vz)

zfsbootmenu is implemented as a Dracut module to provide an experience similar to FreeBSD's bootloader, for Linux distributions. In broad strokes, it works as follows:

* Via GRUB, direct EFI booting, etc, boot a Linux kernel along with an initramfs containing ZFS Boot Menu
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
 * Linux Kernel
 * ZFS on Linux (currently 0.8.3 built on Void Linux).

Binary releases for x86_64 and ppc64le are built on Void Linux hosts. ZFSBootMenu has been successfully tested up to ZFS on Linux 0.8.3 and Dracut 49.

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

On start, ZFS Boot Menu will find the highest versioned kernel in `zroot/ROOT/void.2019.11.01/boot`, confirm that a matching initramfs is present, and default to booting the OS with that.

# Installation

Kernel command-line arguments should be set by setting the ZFS property `org.zfsbootmenu:commandline` on each boot environment. If the property is not defined for a boot environment or its parents, command-line arguments will be taken from the `GRUB_CMDLINE_LINUX_DEFAULT` variable in the file `/etc/default/grub` of the boot environment if the file exist and the variable is defined. Do not set any `root=` or any other pool-related options in the kernel command line; these will be filled in automatically when a boot environment is selected.

For example, I have the following command-line arguments set on my boot environment:

```
zfs.zfs_arc_max=8589934592 elevator=noop
```

Because ZFS properties are inherited by default, it is possible to set the `org.zfsbootmenu:commandline` property on a common parent to apply the same arguments to multiple environments. Setting the property locally on individual boot environments will override the common defaults.

## EFI

ZFS Boot Menu integrates nicely with an EFI system. There will be two key things to configure here.

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


Once `/boot` is backed by ZFS in a boot environment, you'll need to install the boot menu files. Typically, EFI partitions are mounted to `/boot/efi`, and contain a number of sub-directories. In this example, `/boot/efi/EFI/void` holds the ZFS Boot Menu kernel and initramfs.

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
  --label "ZFS Boot Menu" \
  --loader /vmlinuz-0.7.5 \
  --unicode 'root=zfsbootmenu:POOL=zroot ro initrd=\EFI\void\initramfs-0.7.5.img quiet spl_hostid=a8c0a2a8' \
  --verbose
```

Take note to adjust `zfsbootmenu:POOL=`, `spl_hostid=`, `--disk` and `--part` to match your system configuration.

Each time the bootmenu is updated, a new EFI entry will need to be manually added.

### rEFInd

`rEFInd` is considerably easier to install and manage. Refer to your distributions packages for installation. Once rEFInd has been installed, you can create `refind_linux.conf` in the directory holding the ZFS Boot Menu files (`/boot/efi/EFI/void` in our example):

```
"Boot Default BE" "ro quiet loglevel=0 timeout=0 zfsbootmenu:POOL= spl_hostid="
"Select BE" "ro quiet loglevel=0 timeout=-1 zfsbootmenu:POOL= spl_hostid="
```


As with the efibootmgr section, the `zfsbootmenu:POOL=` and `spl_hostid=` options need to be configured to match your environment.

This file will configure `rEFInd` to create two entries for each kernel and initrams pair it finds. The first will directly boot into the environment set via the `bootfs` pool property. The second will force ZFS Boot Menu to display an environment / kernel / snapshot selection menu, allowing you to boot alternate environments, kernels and snapshots.

# Command line options

ZFS Boot Menu currently understands the following options:

* `spl_hostid=` used to set the system hostid if you are using a pre-built initramfs from the release page.
* `force_import=0|1` set to `1` to attempt to force import all pools on the system. Use with caution!
* `read_write=0|1` set to `1` to enable writes to pools when importing. Pools are imported read-only by default as a safety precaution.
* `timeout=`
 * A value of `0` will result in the system immediately booting from the pool configured in the `bootfs` pool property
 * A value of `-1` will result in the system displaying a boot menu.
 * Any other positive value will show a countdown timer to boot the environment configured under `bootfs`, otherwise it will default to a boot menu.
* `""|zfsbootmenu|zfsbootmenu:|zfsbootmenu:POOL=zroot` The first three values are functionally identical. The fourth can be used to prefer a pool if multiple are present in the system.

# ZFS properties

The following properties can be set at whatever level of the pool you'd prefer to control the boot behavior.

* `org.zfsbootmenu:kernel` this can be a partial kernel name `(5.4)` or an explicit name `(vmlinuz-5.6.11_1)`.
* `org.zfsbootmenu:commandline` set the list of kernel commandline options to be passed to the final OS. Do not set `root=`, this is set for you.
* `org.zfsbootmenu:active` controls whether boot environments appear in or are hidden from ZFS Boot Menu:
  - If a boot environment has the property `mountpoint=/`, set `org.zfsbootmenu:active=off` to *hide* the environment. For any other value, including not set, the boot environment will be shown.
  - If a boot environment has the property `mountpoint=legacy`, set `org.zfsbootmenu:active=on` to *show* the environment. For any other value, including not set, the boot environment will be hidden. **Note**: Not all Linux distributions support booting from filesystems with `mountpoint=legacy`.
* `org.zfsbootmenu:rootprefix` controls the prefix added to the ZFS filesystem provided as the root to kernels booted by ZFSBootMenu. For example, the command-line argument `root=zfs:zroot/ROOT/void` has the root prefix `root=zfs:`, which is the default value unless the boot environment appears to be Arch Linux; for Arch, the default root prefix is `zfs=`. Set `org.zfsbootmenu:rootprefix` on any boot environment or its parent to override this default. Remember to include the `root=` component if necessary and any delimiters like `:` or `=` that separate the prefix from the root filesystem.


# initramfs creation

`bin/generate-zbm` can be used to create an initramfs on your system. It ships with void-specific defaults in `etc/config.ini`. To create an initramfs, the following additional tools/libraries will need to be available on your system:

 * [fzf](https://github.com/junegunn/fzf)
 * [kexec-tools](https://github.com/horms/kexec-tools)
 * [mbuffer](http://www.maier-komor.de/mbuffer.html)
 * [perl Config::IniFiles](https://metacpan.org/pod/Config::IniFiles)
 * [perl YAML::PP](https://metacpan.org/pod/YAML::PP)

If you want to create an unified EFI file (kernel, initramfs, command line), you will also need:

* linuxx64.efi.stub (typically packaged with gummiboot)

Your distribution should have packages for these already.

## config.yaml

The YAML file `/etc/zfsbootmenu/config.yaml` is used to control the behavior of `generate-zbm`. In prior versions, an INI file was used; `generate-zbm` will convert an existing `config.ini` file if possible when no `config.yaml` is found.

An example YAML configuration file follows:

```
---
Global:
  ManageImages: false
  BootMountPoint: /boot/efi
  DracutConfDir: /etc/zfsbootmenu/dracut.conf.d
Components:
  ImageDir: /boot/efi/EFI/void
  Versions: false
  Enabled: false
  syslinux:
    Config: /boot/syslinux/syslinux.cfg
    Enabled: false
EFI:
  ImageDir: /boot/efi/EFI/void
  Versions: 2
  Enabled: false
Kernel:
  CommandLine: ro quiet loglevel=0
```

### Global
* `ManageImages` Set this to 1 to allow `generate-zbm` to perform any actions (creation, removal of old files, etc)
* `DracutConfDir` Set this to the location of the dracut configuration director for ZFS Boot Menu. This *CAN NOT* be the same location as the system `dracut.conf.d`, as the configuration files there directly conflict with the creation of the bootmenu initramfs.
* `BootMountPoint` Generally, set this to the location of your ESP. `generate-zbm` will ensure that this is mounted when images are created and, if `generate-zbm` does the mounting, will unmount this filesystem on exit. If you wish to avoid the mount checks, remove this parameter.
* `Version` A specific ZFS Boot Menu version string to use in producing images. In the string, the value `%{current}` will be replaced with the release version of ZFS Boot Menu. The default value is simply the current release version.

### Kernel
* `CommandLine` If you're making a unified EFI file or a syslinux configuration, this is the command line passed to the boot image. Refer to [Command line options](README.md#command-line-options).
* `Path` The full path to a specific kernel to use when making the boot images. If not specified, `generate-zbm` will try to pick a reasonable kernel.
* `Version` A specific kernel version to use. The value "%{current}" will be replaced with the output of `uname -r`; the braces can be omitted if `%current` ends on a word bounary. If not set, `generate-zbm` will try to parse the path of the selected kernel for a version.
* `Prefix` The prefix to use for the names of ZFS Boot Menu images. By default, the prefix is extracted from the input kernel name.

### Components
* `ImageDir` This is the destination directory for the initramfs and kernel.
* `Enabled` Set to `true` to enable creation of separate ZFS Boot Menu kernel and initramfs images. The default value is `false`.
* `Versions` Set to `false` or `0` to disable image versioning; `generate-zbm` will not use its `Global.Version` parameter to name outputs, and will keep exactly one backup copy of every image it produces. Set to `true` (which behaves as `1`) or a positive integer to enable image versioning; `generate-zbm` will append the value of `Global.Version` to every image it produces, followed by a revision as `_$revision`. `generate-zbm` will save `Config.Versions` *revisions* of all images that match the current value of `Global.Versions`. In addition, `generate-zbm` will save the *highest* revision of the most recent `Config.Versions` other image versions found.

### Components.syslinux
* `Enabled` Set to `true` to enable syslinux configuration generation. The default value is `false`.
* `Config` Set to the path of the syslinux configuration file to produce.

### EFI
* `ImageDir` This is the destination directory for the unified EFI file.
* `Enabled` Set to `true` to enable creation of unified UEFI bundles. The default value is `false`.
* `Versions` Behaves similarly to `Components.Versions`, but acts on files matching the UEFI bundle naming scheme.
* `Stub` This is the path to the stub loader used to boot the unified EFI image. If not set, a default of `/usr/lib/gummiboot/linuxx64.efi.stub` is assumed.

# Native encryption

ZFS Boot Menu can import pools or filesystems with native encryption enabled. If your boot environments are not encrypted but say /home is, you will not receive a decryption prompt. To ensure that you can decrypt your pool to load the kernel and initramfs, you'll need to you have the filesystem parameters configured correctly.

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

It's critical that you do not put this key file into the ZFS Boot Menu initramfs, since that file exists on an unencrypted volume - leaving your pool essentially wide-open.

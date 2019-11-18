# Introduction


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
 * Once the count down has been reached for the bootfs-selected environment, prompt to encryption keys if they're needed
     * Mount the filesystem and find the highest-numbered kernel in /boot in the boot environment.     
 * Load the kernel, initramfs and the kernel command line defined in `/etc/default/grub` into memory via kexec
 * Unmount all ZFS filesystems and export all pools
 * Boot the final kernel and initramfs
    
At this point, you'll be booting into your OS-managed kernel and initramfs, along with any arguments needed to correctly boot your system.
 
This tool makes uses of the following additional software:
 * [fzf](https://github.com/junegunn/fzf)
 * [kexec-tools](https://github.com/horms/kexec-tools)
 * Linux (currently 5.3.10)
 * ZFS (currently 0.8.2 for Void Linux).
 
Binary releases for x86_64 and ppc64le are built on Void Linux hosts.

# System prereqs

To ensure the boot menu can find your kernels, you'll need to ensure `/boot` resides on your ZFS file system. An example filesystem layout is as follows:

```
NAME                           USED  AVAIL     REFER  MOUNTPOINT
zroot                          278G   582G       96K  none
zroot/ROOT                    10.9G   582G       96K  none
zroot/ROOT/void.2019.08.20    6.20M   582G     6.13G  /
zroot/ROOT/void.2019.10.04    1.20M   582G     7.17G  /
zroot/ROOT/void.2019.11.01    10.9G   582G     7.17G  /
zroot/home                     120G   582G     11.8G  /home
```

There are three boot environments created, identified by mounting to /.  The environment that this system will boot into is defined by the `bootfs` value set on the `zroot` zpool. 

```
NAME   PROPERTY  VALUE                       SOURCE
zroot  bootfs    zroot/ROOT/void.2019.11.01  local
```

On start, ZFS Boot Menu will find the highest versioned kernel in `zroot/ROOT/void.2019.11.01/boot`, confirm that a matching initramfs is present, and default to booting the OS with that.

# Installation

If you're coming from a legacy installation with `/boot` on EFI, EXT4, etc, you'll need to create `/boot` on the ZFS filesystem and then copy the contents from the old `/boot` into it. 

The file `/etc/default/grub` will need to be created with the variable `GRUB_CMDLINE_LINUX_DEFAULT` defined. These are the kernel arguments passed to the kernel in your boot environment. For example, I have the following set:

```
GRUB_CMDLINE_LINUX_DEFAULT="zfs.zfs_arc_max=8589934592 elevator=noop modprobe.blacklist=ast video=offb:off amdgpu.dc=1 radeon.cik_support=0 amdgpu.cik_support=1 amdgpu.dpm=1"
```

Finally, you'll need to now put the ZFS Boot Menu kernel and initramfs somewhere where a low-level bootloader (Grub, a UEFI implementation, etc) can read them. I have a simple 512M partition on my boot drive that is mounted to `/efi`.

```
# ls /efi | more
vmlinuz-bootmenu
initramfs-bootmenu.img
```

The easiest way now is to add an option to boot into this kernel. You'll need to know the following:
* Your hostid, determined by simply running `hostid`
* Your preferred pool name if you have multiple

From here, you can add an entry via `efibootmgr`:
```
efibootmgr --disk /dev/sda \
  --part 1 \
  --create \
  --label "ZFS Boot Menu" \
  --loader /vmlinuz-bootmenu \
  --unicode 'root=zfsbootmenu:POOL=zroot ro initrd=\initramfs-bootmenu.img quiet spl_hostid=`hostid`' \
  --verbose
```

This command assumes that both the kernel and the initramfs are in the top level directory of your EFI partition. From here, you will be able to reboot and pick `ZFS Boot Menu` from your UEFI boot menu, and then from there boot into your ZFS boot environment.

# Native encryption

ZFS Boot Menu can import pools or filesystems with native encryption enabled. If your boot environments are not encrypted but say /home is, you will not receive a decryption prompt. To ensure that you can decrypt your pool to load the kernel and initramfs, you'll need to ensure that you have the the filesystem parameters configured correctly.

```
zfs get all zroot | egrep '(encryption|keylocation|keyformat)'
Password: 
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

# Limitations

Currently, the kernel command line for the boot environment is read from `/etc/default/grub`. I'd like to support multiple locations determined by probing the OS installed in the boot environment. 

When building a kernel command line to pass to the kexec'd kernel, the command line generated is always created for Dracut's ZFS module. Again, this will need to be modified based on the detected OS in the boot environment.

Both of the above issues are readily resolved by hopefully reading /etc/os-release from the boot environment and acting based on that.

Because this is implemented as a full kernel and initramfs, it doesn't really fit into the way your distribution ships/installs packages. It doesn't make any sense for your OS to install these two files into `/boot`. They need to be placed in an implementation-dependenant location so that GRUB, EFI, etc can read them. This makes updating the boot menu on an installed system slightly more burdensome, since your normal package update process won't see updates.

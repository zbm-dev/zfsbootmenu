# Void full disk encryption install process

Download the latest [hrmpf](https://github.com/leahneukirchen/hrmpf/releases), write it to USB drive and boot your system in EFI mode. You can confirm you've booted in EFI mode by running `efibootmgr`. 

For this guide, the following assumptions are made:
* `/dev/sda` is the drive dedicated for the ZFS pool
* `/dev/sdb` is the USB drive dedicated for the EFI partition
* You're mildly comfortable with ZFS, EFI and discovering system facts on your own (`lsblk`, `dmesg`, `gdisk`, ...)

# ZFS prep work

* Build and load ZFS modules
```
xbps-reconfigure -a
modprobe zfs
```
* Generate /etc/hostid
```
zgenhostid
```
* Store your pool passphrase in a key file
```
echo "SomeKeyphrase" > /etc/zfs/zroot.key
chmod 000 /etc/zfs/zroot.key
```

# ZFS pool creation

* Create the zpool
```
zpool create -f -o ashift=12 \
 -O compression=lz4 \
 -O acltype=posixacl \
 -O xattr=sa \
 -O relatime=on \
 -O encryption=aes-256-gcm \
 -O keylocation=file:///etc/zfs/zroot.key \
 -O keyformat=passphrase \
 -o autotrim=on \
 -m none zroot /dev/sda
```
It's out of the scope of this guide to cover all of the pool creation options used - feel free to tailor them to suit your system. However, the following options need to be addressed:
* `encryption=aes-256-gcm` - You can adjust the algorithm as you see fit, but this will likely be the most performant on modern x86_64 hardware.
* `keylocation=file:///etc/zfs/zroot.key` - This sets our pool encryption passphrase to the file `/etc/zfs/zroot.key`, which we created in a previous step. This file will live inside your initramfs stored ON the ZFS boot environment.
* `keyformat=passphrase` - By setting the format to `passphrase`, we can now force a prompt for this in `zfsbootmenu`. It's critical that your passphrase be something you can type on your keyboard, since you will need to type it in to unlock the pool on boot.

* Create our initial file systems
```
zfs create -o mountpoint=none zroot/ROOT
zfs create -o mountpoint=/ zroot/ROOT/void.$( date +%Y.%m.%d)
zfs create -o mountpoint=/home zroot/home
```
* Export, then reimport with a temporary mountpoint of /mnt
```
zpool export zroot
zpool import -l -R /mnt zroot
```

# Install Void
* Adjust the mirror / libc / package selection as you see fit
```
xbps-install -S -R https://mirrors.servercentral.com/voidlinux/current -r /mnt base-system zfs vim efibootmgr pigz
```
* Copy a few files into the chroot
```
cp /etc/hostid /mnt/etc
cp /etc/resolv.conf /mnt/etc/
cp /etc/zfs/zroot.key /mnt/etc/zfs
```
* Chroot into the new OS
```
mount -t proc proc /mnt/proc
mount -t sysfs sys /mnt/sys
mount -B /dev /mnt/dev
mount -t devpts pts /mnt/dev/pts
chroot /mnt
```
# Basic Void configuration
* Set a keymap
```
echo "KEYMAP=\"us\"" >> /etc/rc.conf
```
* Set a time zone
```
echo "TIMEZONE=\"America/Chicago\"" >> /etc/rc.conf
```
* Configure the hardware clock
```
echo "HARDWARECLOCK=\"UTC\"" >> /etc/rc.conf
```
* Configure your glibc locale
```
cp /etc/default/libc-locales /etc/default/libc-locales.dist
echo "en_US.UTF-8 UTF-8" > /etc/default/libc-locales
echo "en_US ISO-8859-1" >> /etc/default/libc-locales
xbps-reconfigure -f glibc-locales
```
* Set a root password
```
passwd
```

# ZFS Configuration
* To more quickly discover and import pools on boot, we need to set a pool cachefile
```
zpool set cachefile=/etc/zfs/zpool.cache zroot
```
* Configure our default boot environment
```
zpool set bootfs=zroot/ROOT/void.$( date +Y.%m.%d ) zroot
```
* Configure Dracut to load ZFS support
```
cat << EOF > /etc/dracut.conf.d/zol.conf
nofsck="yes"
add_dracutmodules+=" zfs "
omit_dracutmodules+=" btrfs "
install_items+=" /etc/zfs/zroot.key "
EOF
```
* Rebuild the initramfs
```
xbps-reconfigure -f linux5.4
```
# Install and configure ZFSBootMenu

* Create /etc/default/grub . This is read by `ZFSBootMenu` to know what kernel command line arguments are needed to boot the final kernel.
```
echo "GRUB_CMDLINE_LINUX_DEFAULT=\"spl_hostid=$( hostid ) ro quiet\"" > /etc/default/grub
```

* Create an EFI partition on `/dev/sdb`
```
gdisk /dev/sdb
GPT fdisk (gdisk) version 1.0.4

Partition table scan:
  MBR: protective
  BSD: not present
  APM: not present
  GPT: present

Found valid GPT with protective MBR; using GPT.

Command (? for help): p
Disk /dev/sdb: 62656641 sectors, 29.9 GiB
Model: Flash Drive FIT 
Sector size (logical/physical): 512/512 bytes
Disk identifier (GUID): 957513EB-C1FF-A74D-B3C1-55CEBBC72DFA
Partition table holds up to 128 entries
Main partition table begins at sector 2 and ends at sector 33
First usable sector is 2048, last usable sector is 62656607
Partitions will be aligned on 2048-sector boundaries
Total free space is 61605984 sectors (29.4 GiB)

Command (? for help): n
Partition number (1-128, default 1): 1
First sector (1050624-62656607, default = 1050624) or {+-}size{KMGTP}: 
Last sector (1050624-62656607, default = 62656607) or {+-}size{KMGTP}: +512M
Current type is 'Linux filesystem'
Hex code or GUID (L to show codes, Enter = 8300): EF00
Changed type of partition to 'EFI System'

Command (? for help): 
```

* Create a vfat filesystem
```
mkfs.vfat -F32 /dev/sdb1
```

* Create an fstab entry and mount
```
cat << EOF >> /etc/fstab
$( blkid | grep /dev/sdb1 | cut -d ' ' -f 2 ) /boot/efi vfat defaults,noauto 0 0
EOF
mkdir /boot/efi
mount /boot/efi
```

* Install rEFInd
This should find /boot/efi as your EFI partition and install itself accordingly. 
```
xbps-install -Rs refind
refind-install
rm /boot/refind_linux.conf
```

* Install the bootmenu package
```
xbps-install -Rs zfsbootmenu
```
* Enable zfsbootmenu image creation
Edit /etc/zfsbootmenu/config.ini and set:
 * Manage=1 under [General] section
 * Copies=3 under [Components] section
 * See [Configuration options](https://github.com/zdykstra/zfsbootmenu#installation) for more details.
```
[Global]
ManageImages=1
DracutConfDir=/etc/zfsbootmenu/dracut.conf.d
BootMountPoint=/boot/efi

[Kernel]
CommandLine=ro quiet loglevel=0

[Components]
ImageDir=/boot/efi/EFI/void
Versioned=1
Copies=3

[EFI]
ImageDir=/boot/efi/EFI/void
Versioned=1
Copies=0

[syslinux]
CreateConfig=0
Config=/boot/efi/syslinux/syslinux.cfg
```
* Generate the initial bootmenu initramfs
```
xbps-reconfigure -f zfsbootmenu
zfsbootmenu: configuring ...
Creating ZFS Boot Menu 0.8.1_1, with vmlinuz 5.4.15_1
Found 0 existing images, allowed to have a total of 3
Created /boot/efi/EFI/void/vmlinuz-0.8.1_1, /boot/efi/EFI/void/initramfs-0.8.1_1.img
```
* Create /boot/efi/EFI/void/refind_linux.conf
```
cat << EOF > /boot/efi/EFI/void/refind_linux.conf
"Boot default"  "zfsbootmenu:ROOT=zroot spl_hostid=$( hostid ) timeout=0 ro quiet loglevel=0"
"Boot to menu"  "zfsbootmenu:ROOT=zroot spl_hostid=$( hostid ) timeout=-1 ro quiet loglevel=0"
EOF
```
* Exit the chroot, unmount everything
```
exit
umount -n /mnt/{dev/pts,dev,sys,proc}
umount /mnt/boot/efi
```
* Export the zpool and reboot
```
zpool export zroot
reboot
```

Debian Bullseye UEFI Installation
=================================

.. contents:: Contents
  :depth: 2
  :local:
  :backlinks: none

Preparation
-----------

Download the `Debian Bullseye (11) Live image <https://www.debian.org/CD/live/>`_ and write it to a USB drive. Grab the
most recent image.

Disable Secure Boot on your system. Because ZFS modules are built using the ``zfs-dkms`` package, the modules will not
be signed and will be unusable in a Secure Boot setup. The modules may be signed for use with Secure Boot, but that is
beyond the scope of this document.

Blindly copying and pasting this commands most likely will not work. take some time to understand ZFS and boot proccess.
First read the whole guide at least once and then start the installation.

Early Setup
-----------

Boot the USB/CD/DVD/... drive containing the live image.

Log in as root. most of the following commands need root access::

  sudo su --login

Configure APT and update the package database::

  cat <<EOF > /etc/apt/sources.list
  deb http://deb.debian.org/debian bullseye main contrib
  deb-src http://deb.debian.org/debian bullseye main contrib
  EOF
  apt update

You may see faster downloads replacing ``deb.debian.org`` with a local mirror. If you want to use HTTPS transport, make
sure that the ``ca-certificates`` and ``apt-transport-https`` packages are installed and your mirror has a valid
certificate; otherwise, apt will refuse to use the mirror.

Install fundamental packages in live system::

  apt install debootstrap gdisk parted dkms linux-headers-$(uname -r)
  apt install zfsutils-linux

Disk Preparation
----------------

For disk operations, it is assumed that the environment variable ``TARGET_DISK`` points to a single disk on which you
wish to create a ZFS pool.

Create partition table
~~~~~~~~~~~~~~~~~~~~~~

.. caution::

  This action will delete all data on your drive.

This example creates two partitions: one EFI system partition and another on which the ZFS pool will be stored. Adjust
this to suit your needs. You may find it easier to use ``cgdisk`` insteade of ``sgdisk`` to partition your drive.

.. code-block::

  sgdisk --zap-all $TARGET_DISK
  sgdisk -n1:1m:+512m -t1:ef00 $TARGET_DISK
  sgdisk -n2:0:0 -t2:bf00 $TARGET_DISK

Running ``lsblk`` will confirm that the kernel has recognized the new partitions. If the output does not contain created
partitions, run ``partprobe`` to inform the kernel of partition table changes. If that didnt work, reboot.

Format EFI system partition (ESP)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For this step, it is assumed that the environment variable ``TARGET_ESP`` points to the first partition created in the
preceding step.

.. code-block::

  mkfs -t vfat -F 32 -s 1 -n EFI $TARGET_ESP

The ``-s 1`` flag is only necessary for drives which present 4 KiB logical sectors ("4Kn" drives) to meet the minimum
cluster size (given the partition size of 512 MiB) for FAT32. It also works fine on drives which present 512 B sectors.

Create a ZFS pool
~~~~~~~~~~~~~~~~~

If you want encryption, store a pool passphrase in a key file::

  echo '<your-passphrase-here>' > /etc/zfs/zroot.key
  chmod 000 /etc/zfs/zroot.key

Create the pool. When specifying devices for ZFS vdevs, it is generally advisable to use persistent disk names created
by ``udev`` in one of the ``/dev/disk`` subdirectories. Both ``by-id`` and (on GPT disks) ``by-partuuid`` subdirectories
are good choices as ZFS vdev targets. Using ordinary block device nodes may cause import problems if your disk
configuration eventually changes. For this example, it is assumed that the environment variable ``TARGET_VDEV`` contains
the path to the second partition created above.

.. code-block::

  zpool create -f \
        -o ashift=12 \
        -o autotrim=on \
        -O encryption=aes-256-gcm \
        -O keylocation=file:///etc/zfs/zroot.key \
        -O keyformat=passphrase \
        -O acltype=posixacl \
        -O compression=lz4 \
        -O normalization=formD \
        -O relatime=on \
        -O xattr=sa \
        -O mountpoint=none \
        -R /mnt \
        zroot $TARGET_VDEV

If you are not using encryption, omit the following options:

.. code-block::

  -O encryption=aes-256-gcm
  -O keylocation=file:///etc/zfs/zroot.key
  -O keyformat=passphrase

Create filesystems to hold the Debian boot environment and home directories::

  zfs create zroot/ROOT
  zfs create -o canmount=noauto -o mountpoint=/ zroot/ROOT/debian
  zfs mount zroot/ROOT/debian
  zfs create -o mountpoint=/home zroot/home

.. note::

  It is important to set ``canmount=noauto`` on any filesystem with ``mountpoint=/`` to prevent the ZFS automount
  process from attempting to mount more than one boot environment at the root of the filesystem. It is also possible to
  set ``mountpoint=legacy`` on boot environments, but filesystems with ``mountpoint=legacy`` will not be examined by
  ZFSBootMenu unless the property ``org.zfsbootmenu:active=on`` is also set.

Set the default boot environment to tell ZFSBootMenu what it should prefer to boot::

  zpool set bootfs=zroot/ROOT/debian zroot

Re-import the pool with a temporary root to populate the filesystems::

  zpool export zroot
  zpool import -N -R /mnt zroot
  zfs load-key zroot # only if encrypted
  zfs mount zroot/ROOT/debian
  zfs mount -a

Mount EFI system partition where it will reside in the target system::

  mkdir -p /mnt/boot/efi
  mount $TARGET_ESP /mnt/boot/efi

Install the Debian base::

  debootstrap bullseye /mnt

If you want, you can specify a mirror by appending its URL to the above command.

Copy the pool key (for an encrypted pool) and resolv.conf into the new installation::

  cp /etc/resolv.conf /mnt/etc/
  mkdir -p /mnt/etc/zfs
  cp /etc/zfs/zroot.key /mnt/etc/zfs/

Set a hostname and add it to the hosts file::

  echo 'YOURHOSTNAME' > /mnt/etc/hostname
  echo -e '127.0.1.1\tYOURHOSTNAME' >> /mnt/etc/hosts

Bind virtual filesystems from the live environment into the target hierarchy, then chroot into the target system::

  for i in dev sys proc run; do
      mount --rbind /$i /mnt/$i
      mount --make-rslave /mnt/$i
  done
  chroot /mnt env TARGET_ESP="$TARGET_ESP" TARGET_VDEV="$TARGET_VDEV" bash --login

Customize the installation
--------------------------

At this point, the installation process looks like any other Linux setup procedure. Major steps are highlighted for
convenience, but the process may be adapted as you see fit.

Basic configuration
~~~~~~~~~~~~~~~~~~~

Set a root password for installed system. you can disable login as root later, when you have created another user with
``sudo`` privilege.

.. code-block::

  passwd

Configure ``apt``. Use other mirrors if you prefer.

.. code-block::

  cat <<EOF > /etc/apt/sources.list
  deb http://deb.debian.org/debian bullseye main contrib
  deb-src http://deb.debian.org/debian bullseye main contrib

  deb http://deb.debian.org/debian-security/ bullseye-security main contrib
  deb-src http://deb.debian.org/debian-security/ bullseye-security main contrib

  deb http://deb.debian.org/debian bullseye-updates main contrib
  deb-src http://deb.debian.org/debian bullseye-updates main contrib

  deb http://deb.debian.org/debian bullseye-backports main contrib
  deb-src http://deb.debian.org/debian bullseye-backports main contrib
  EOF

Do not use HTTPS as a transport protocol yet. The packages ``ca-certificates`` and ``apt-transport-https`` are not
installed. After installing and configuring the ``locales`` package, it will be possible to install ``ca-certificates``
and ``apt-transport-https`` and switch to HTTPS transports.

Update the repository cache and install upgrades if any are available::

  apt update
  apt full-upgrade

Install essential packages and ``bash-completion`` to make typing commands easier::

  apt install locales console-setup bash-completion
  . /usr/share/bash-completion/bash_completion

Configure packages to customize local and console properties::

  dpkg-reconfigure locales tzdata keyboard-configuration console-setup

.. note::

  You should always enable the `en_US.UTF-8` locale because some programs require it.

Install packages necessary to support ZFS::

  apt install linux-headers-amd64 linux-image-amd64 refind git zfs-initramfs
  echo "REMAKE_INITRD=yes" > /etc/dkms/zfs.conf

When rEFInd offers to make edits to your ESP partition, check to make sure that it mounted the correct partition::

  mount | grep /boot

On systems with multiple bootable drives, rEFInd may mount more than one ESP partition when it makes changes. You may
have to manually copy the ``/boot/efi/EFI/refind`` directory to a temporary directory, unmount the unwanted ESP
partitions so only the ``$TARGET_ESP`` partition is mounted, and then move the directory back.

Verify that your ZFS pool passphrase is stored in ``/etc/zfs/zroot.key`` and that permissions are 000::

  echo -n ZFS passphrase: && cat /etc/zfs/zroot.key
  echo -n Permissions: && ls -aFl /etc/zfs/zroot.key

Set the ``cachefile`` property for your pool::

  zpool set cachefile=/etc/zfs/zpool.cache zroot

Enable systemd zfs services::

  systemctl enable zfs.target
  systemctl enable zfs-import-cache
  systemctl enable zfs-mount
  systemctl enable zfs-import.target

Create ``/etc/fstab`` to make sure your EFI system partition will be mounted::

  cat > /etc/fstab <<EOF
  $(blkid -s PARTUUID -o export $TARGET_ESP | grep '^PARTUUID=') /boot/efi vfat defaults 0 1
  EOF

Configure ``initramfs-tools``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Because the encryption key is stored in ``/etc/zfs`` directory, it will automatically be copied into the system
initramfs.

.. note::

  The pool key will be stored in kernel initramfs in plain text. Never move this initramfs image off of the encrypted
  pool! In addition, it is strongly recommended that the initramfs be created with permissions that prevent users from
  inspecting its contents::

    echo "UMASK=0077" > /etc/initramfs-tools/conf.d/umask.conf

Set up ZFSBootMenu
~~~~~~~~~~~~~~~~~~

Set a desired kernel command line for the boot environment, *e.g.*::

  zfs set org.zfsbootmenu:commandline="quiet" zroot/ROOT

Install ZFSBootMenu. There is no pre-built package for Debian, so we need to install from source.::

  mkdir -p /usr/local/src
  cd /usr/local/src
  git clone 'https://github.com/zbm-dev/zfsbootmenu.git'
  cd zfsbootmenu
  make core dracut

Configure ZFSBootMenu to build images. (It may be easier to modify the configuration in an editor).

.. code-block::

  sed -i -e "s|ManageImages: false|ManageImages: true|" /etc/zfsbootmenu/config.yaml

Install required dependencies::

  apt install libconfig-inifiles-perl libsort-versions-perl libboolean-perl libyaml-pp-perl fzf mbuffer kexec-tools dracut-core

Choose 'No' when asked if kexec-tools should handle reboots.

.. note::

  Do not install ``dracut`` instead of ``dracut-core`` because the former conflicts with ``initramfs-tools``, requires
  advanced configuration to boot your system. The ``dracut-core`` package coexists with ``initramfs-tools``, does not
  alter standard system behavior, and provides everything needed by ZFSBootMenu.

Generate the system initramfs::

  update-initramfs -c -k all

Generate a ZFSBootMenu image::

  generate-zbm

Configure rEFInd to boot the ZFSBootMenu image::

  cat > /boot/efi/EFI/debian/refind_linux.conf <<EOF
  "Boot default"  "zbm.prefer=zroot zbm.skip loglevel=4"
  "Boot to menu"  "zbm.prefer=zroot zbm.show loglevel=4"
  EOF

(Optional) You may need to add rEFInd to your EFI boot order manually::

  apt install efibootmgr

  # List existing boot items
  efibootmgr

  # Add refind as a boot item
  efibootmgr -c -d $TARGET_ESP -l "\\EFI\\refind\\refind_x64.efi" -L rEFInd

Exit the chroot and reboot::

  exit
  cd /
  umount -R /mnt
  zpool export -a
  reboot

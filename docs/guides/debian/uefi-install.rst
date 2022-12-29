Debian Bullseye UEFI Installation
=================================

.. contents:: Contents
  :depth: 2
  :local:
  :backlinks: none

Preparation
-----------

This guide can be used to install Debian onto a single disk with or without ZFS encryption.

It assumes the following:

* Your system uses UEFI to boot
* Your system is x86_64
* ``/dev/sda`` is the onboard SSD, used for both ZFS and EFI
* You're mildly comfortable with ZFS, EFI and discovering system facts on your own (``lsblk``, ``dmesg``, ``gdisk``, ...)

Download the latest `Debian Bullseye (11) Live image <https://www.debian.org/CD/live/>`_, write it to a USB drive and
boot your system in EFI mode. You can confirm you've booted in EFI mode by running ``efibootmgr``.

Early Setup
-----------

Switch to a root shell
~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  sudo su --login

Configure and update APT
~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  cat <<EOF > /etc/apt/sources.list
  deb http://deb.debian.org/debian bullseye main contrib
  deb-src http://deb.debian.org/debian bullseye main contrib
  EOF
  apt update

.. note::

  You may see faster downloads replacing ``deb.debian.org`` with a local mirror. If you want to use HTTPS transport, make
  sure that the ``ca-certificates`` and ``apt-transport-https`` packages are installed and your mirror has a valid
  certificate; otherwise, apt will refuse to use the mirror.

Install helpers
~~~~~~~~~~~~~~~

.. code-block::

  apt install debootstrap gdisk dkms linux-headers-$(uname -r)
  apt install zfsutils-linux

SSD prep work
----------------

Create partitions on ``/dev/sda``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. caution::

  This action will delete all data on ``/dev/sda``

.. code-block::

  sgdisk --zap-all /dev/sda
  sgdisk -n1:1m:+512m -t1:ef00 /dev/sda
  sgdisk -n2:0:0 -t2:bf00 /dev/sda

ZFS pool creation
-----------------

Create the zpool
~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Encrypted

    .. code-block::

      echo 'SomeKeyphrase' > /etc/zfs/zroot.key
      chmod 000 /etc/zfs/zroot.key

      zpool create -f -o ashift=12 \
       -O compression=lz4 \
       -O acltype=posixacl \
       -O xattr=sa \
       -O relatime=on \
       -O encryption=aes-256-gcm \
       -O keylocation=file:///etc/zfs/zroot.key \
       -O keyformat=passphrase \
       -o autotrim=on \
       -m none zroot /dev/sda2

    It's out of the scope of this guide to cover all of the pool creation options used - feel free to tailor them to suit
    your system. However, the following options need to be addressed:

    * ``encryption=aes-256-gcm`` - You can adjust the algorithm as you see fit, but this will likely be the most performant
      on modern x86_64 hardware.
    * ``keylocation=file:///etc/zfs/zroot.key`` - This sets our pool encryption passphrase to the file
      ``/etc/zfs/zroot.key``, which we created in a previous step. This file will live inside your initramfs stored *on* the
      ZFS boot environment.
    * ``keyformat=passphrase`` - By setting the format to ``passphrase``, we can now force a prompt for this in
      ``zfsbootmenu``. It's critical that your passphrase be something you can type on your keyboard, since you will need to
      type it in to unlock the pool on boot.

  .. group-tab:: Unencrypted

    .. code-block::

      zpool create -f -o ashift=12 \
       -O compression=lz4 \
       -O acltype=posixacl \
       -O xattr=sa \
       -O relatime=on \
       -o autotrim=on \
       -m none zroot /dev/sda2

Create our initial file systems
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  zfs create -o mountpoint=none zroot/ROOT
  zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/debian
  zfs create -o mountpoint=/home zroot/home

.. note::

  It is important to set the property ``canmount=noauto`` on any file systems with ``mountpoint=/`` (that is, on
  any additional boot environments you create). Without this property, Debian will attempt to automount all ZFS file
  systems and fail when multiple file systems attempt to mount at ``/``; this will prevent your system from booting.
  Automatic mounting of ``/`` is not required because the root file system is explicitly mounted in the boot process.

  Also note that, unlike many ZFS properties, ``canmount`` is not inheritable. Therefore, setting ``canmount=noauto`` on
  ``zroot/ROOT`` is not sufficient, as any subsequent boot environments you create will default to ``canmount=on``. It is
  necessary to explicitly set the ``canmount=noauto`` on every boot environment you create.

Export, then re-import with a temporary mountpoint of ``/mnt``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Encrypted

    .. code-block::

      zpool export zroot
      zpool import -N -R /mnt zroot
      zfs load-key -L prompt zroot
      zfs mount zroot/ROOT/debian
      zfs mount zroot/home

  .. group-tab:: Unencrypted

    .. code-block::

      zpool export zroot
      zpool import -N -R /mnt zroot
      zfs mount zroot/ROOT/debian
      zfs mount zroot/home

Verify that everything is mounted correctly
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  # mount | grep mnt
  zroot/ROOT/debian on /mnt type zfs (rw,relatime,xattr,posixacl)
  zroot/home on /mnt/home type zfs (rw,relatime,xattr,posixacl)


Install Debian
--------------

.. code-block::

  debootstrap bullseye /mnt

Copy files into the new install
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Encrypted

    .. code-block::

      cp /etc/hostid /mnt/etc/hostid
      cp /etc/resolv.conf /mnt/etc/
      mkdir -p /mnt/etc/zfs
      cp /etc/zfs/zroot.key /mnt/etc/zfs/

  .. group-tab:: Unencrypted

    .. code-block::

      cp /etc/hostid /mnt/etc/hostid
      cp /etc/resolv.conf /mnt/etc

Chroot into the new OS
~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  for i in dev sys proc run; do
      mount --rbind /$i /mnt/$i
      mount --make-rslave /mnt/$i
  done
  chroot /mnt bash --login

Basic Debian Configuration
--------------------------

Set a hostname
~~~~~~~~~~~~~~

.. code-block::

  echo 'YOURHOSTNAME' > /etc/hostname
  echo -e '127.0.1.1\tYOURHOSTNAME' >> /etc/hosts

Set a root password
~~~~~~~~~~~~~~~~~~~

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

Update the repository cache
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code::

  apt update

Install additional base packages
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code::

  apt install locales keyboard-configuration console-setup

Configure packages to customize local and console properties
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  dpkg-reconfigure locales tzdata keyboard-configuration console-setup

.. note::

  You should always enable the `en_US.UTF-8` locale because some programs require it.

ZFS Configuration
-----------------

Install required packages
~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  apt install linux-headers-amd64 linux-image-amd64 git zfs-initramfs dosfstools
  echo "REMAKE_INITRD=yes" > /etc/dkms/zfs.conf

Set up pool caching
~~~~~~~~~~~~~~~~~~~

To more quickly discover and import pools on boot, we need to set a pool cachefile::

  zpool set cachefile=/etc/zfs/zpool.cache zroot

Configure our default boot environment
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  zpool set bootfs=zroot/ROOT/debian zroot

Enable systemd ZFS services
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  systemctl enable zfs.target
  systemctl enable zfs-import-cache
  systemctl enable zfs-mount
  systemctl enable zfs-import.target

Configure ``initramfs-tools``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Encrypted

    .. code-block::

      echo "UMASK=0077" > /etc/initramfs-tools/conf.d/umask.conf

    .. note::

      Because the encryption key is stored in ``/etc/zfs`` directory, it will automatically be copied into the system
      initramfs.

  .. group-tab:: Unencrypted

    No required steps


Rebuild the initramfs
~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  update-initramfs -c -k all

Set ZFSBootMenu properties on datasets
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Assign command-line arguments to be used when booting the final kernel. Because ZFS properties are inherited, assign the
common properties to the ``ROOT`` dataset so all children will inherit common arguments by default.

.. code-block::

  zfs set org.zfsbootmenu:commandline="quiet" zroot/ROOT

Install and configure ZFSBootMenu
---------------------------------

Create and mount an ESP
~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  mkfs.vfat -F32 /dev/sda1

  cat <<EOF >/etc/fstab
  $(blkid -s PARTUUID -o export /dev/sda1 | grep '^PARTUUID=') /boot/efi vfat defaults 0 1
  EOF

  mkdir /boot/efi
  mount /boot/efi

Install ZFSBootMenu
~~~~~~~~~~~~~~~~~~~

.. code-block::

  mkdir -p /usr/local/src
  cd /usr/local/src
  git clone 'https://github.com/zbm-dev/zfsbootmenu.git'
  cd zfsbootmenu
  make core dracut

Install required ZFSBootMenu dependencies
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  apt install libsort-versions-perl \
    libboolean-perl \
    libyaml-pp-perl \
    fzf \
    mbuffer \
    kexec-tools \
    dracut-core \
    efibootmgr \
    bsdextrautils

.. note::

  Choose 'No' when asked if kexec-tools should handle reboots.

Adjust ``/etc/zfsbootmenu/config.yaml``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: yaml

   Global:
    ManageImages: true
    BootMountPoint: /boot/efi
    DracutConfDir: /etc/zfsbootmenu/dracut.conf.d
    PreHooksDir: /etc/zfsbootmenu/generate-zbm.pre.d
    PostHooksDir: /etc/zfsbootmenu/generate-zbm.post.d
    InitCPIOConfig: /etc/zfsbootmenu/mkinitcpio.conf
  Components:
    ImageDir: /boot/efi/EFI/zbm
    Versions: 3
    Enabled: false
  EFI:
    ImageDir: /boot/efi/EFI/zbm
    Versions: false
    Enabled: true
  Kernel:
    CommandLine: ro quiet loglevel=0

Generate the initial ZFSBootMenu images
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  generate-zbm
  cp /boot/efi/EFI/zbm/vmlinuz.EFI /boot/efi/EFI/zbm/vmlinuz-backup.EFI

Add UEFI boot entries
~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  efibootmgr -c -d /dev/sda -p 1 -L "ZFSBootMenu (Backup)" -l \\EFI\\ZBM\\VMLINUZ-BACKUP.EFI
  efibootmgr -c -d /dev/sda -p 1 -L "ZFSBootMenu" -l \\EFI\\ZBM\\VMLINUZ.EFI

Exit the chroot and reboot
~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  exit
  cd /
  umount -R /mnt
  reboot

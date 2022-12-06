Single-disk syslinux MBR
========================

.. contents:: Contents
  :depth: 2
  :local:
  :backlinks: none

This guide can be used to install Void onto a single ZFS disk with or without ZFS encryption. It assumes the following:

* Your system uses BIOS to boot
* Your system is x86_64
* You will use ``glibc`` as your system libc.
* ``/dev/sda`` is the onboard SSD, used for ZFS and syslinux
* You're mildly comfortable with ZFS and discovering system facts on your own (``lsblk``, ``dmesg``, ``gdisk``, ...)

.. include:: _include/intro.rst

Download the latest `hrmpf <https://github.com/leahneukirchen/hrmpf/releases>`_, write it to USB drive and boot your
system in BIOS mode.

.. include:: _include/zfs-prep.rst

SSD prep work
-------------

Create a syslinux partition on ``/dev/sda``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: none

  bash-5.0# fdisk /dev/sda

  Welcome to fdisk (util-linux 2.35.2).
  Changes will remain in memory only, until you decide to write them.
  Be careful before using the write command.


  Command (m for help): o
  Created a new DOS disklabel with disk identifier 0xf5f142cb.

  Command (m for help): n
  Partition type
     p   primary (0 primary, 0 extended, 4 free)
     e   extended (container for logical partitions)
  Select (default p): p
  Partition number (1-4, default 1): 1
  First sector (2048-1000215215, default 2048): 
  Last sector, +/-sectors or +/-size{K,M,G,T,P} (2048-1000215215, default 1000215215): +512M

  Created a new partition 1 of type 'Linux' and of size 512 MiB.

  Command (m for help): n
  Partition type
     p   primary (1 primary, 0 extended, 3 free)
     e   extended (container for logical partitions)
  Select (default p): p
  Partition number (2-4, default 2): 2
  First sector (1050624-1000215215, default 1050624): 
  Last sector, +/-sectors or +/-size{K,M,G,T,P} (1050624-1000215215, default 1000215215): 

  Created a new partition 2 of type 'Linux' and of size 476.4 GiB.

  Command (m for help): a
  Partition number (1,2, default 2): 1

  The bootable flag on partition 1 is enabled now.

  Command (m for help): w
  The partition table has been altered.
  Calling ioctl() to re-read partition table.
  Syncing disks.

.. include:: _include/pool-creation-non-detached.rst

.. include:: _include/create-filesystems.rst

.. include:: _include/install.rst

.. include:: _include/zfs-config.rst

Install and configure ZFSBootMenu
---------------------------------

Create an ext4 filesystem on ``/dev/sda1``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  mkfs.ext4 -O '^64bit' /dev/sda1

.. note::

  Under some circumstances, syslinux may fail to recognize files on an ext4 filesystem. The issue may be related to the
  ``64bit`` feature of the filesystem, which is explicitly disabled in the command above. If syslinux still fails to
  recognize files on the ext4 partition, try using ext3 or ext2 as a fallback.

Create an fstab entry and mount
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  cat << EOF >> /etc/fstab
  $( blkid | grep /dev/sda1 | cut -d ' ' -f 2 ) /boot/syslinux ext4 defaults 0 0
  EOF
  mkdir /boot/syslinux
  mount /boot/syslinux

Install the syslinux package, copy modules
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  xbps-install -S syslinux
  cp /usr/lib/syslinux/*.c32 /boot/syslinux

Install extlinux
~~~~~~~~~~~~~~~~

.. code-block::

  bash-5.0# extlinux --install /boot/syslinux
  /boot/syslinux is device /dev/sda1


Install the syslinux MBR data
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: none

  bash-5.0# dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/mbr.bin of=/dev/sda
  1+0 records in
  1+0 records out
  440 bytes copied, 0.000306845 s, 1.4 MB/s

.. include:: _include/zbm-setup.rst

Enable zfsbootmenu image creation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Edit ``/etc/zfsbootmenu/config.yaml`` and set:

* ``ManageImages: true`` and ``BootMountPoint: /boot/syslinux`` under the ``Global`` section
* ``ImageDir: /boot/syslinux/zfsbootmenu``, ``Versions: 3`` and ``Enabled: true`` under the ``Components`` section
* ``Enabled: true`` under the ``Components.syslinux`` section

See :doc:`generate-zbm(5) </man/generate-zbm.5>` for more details.

Sample /etc/zfsbootmenu/config.yaml
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: yaml

  Global:
    ManageImages: true
    BootMountPoint: /boot/syslinux
    DracutConfDir: /etc/zfsbootmenu/dracut.conf.d
  Components:
    ImageDir: /boot/syslinux/zfsbootmenu
    Versions: 3
    Enabled: true
    syslinux:
      Config: /boot/syslinux/syslinux.cfg
      Enabled: true
  EFI:
    ImageDir: /boot/efi/EFI/void
    Versions: 2
    Enabled: false
  Kernel:
    CommandLine: quiet loglevel=0

.. include:: _include/gen-initramfs.rst

.. include:: _include/cleanup.rst

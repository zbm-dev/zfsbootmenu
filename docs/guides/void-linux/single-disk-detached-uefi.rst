Single-disk detached UEFI
=========================

.. contents:: Contents
  :depth: 2
  :local:
  :backlinks: none

This guide can be used to install Void onto a single ZFS disk with or without ZFS encryption. The EFI partition will be
created on a removable disk. It assumes the following:

* Your system uses UEFI to boot
* Your system is x86_64
* You will use ``glibc`` as your system libc.
* ``/dev/sda`` is the onboard SSD, used for ZFS
* ``/dev/sdb`` is a dedicated USB drive, used for the EFI partition
* You're mildly comfortable with ZFS, EFI and discovering system facts on your own (``lsblk``, ``dmesg``, ``gdisk``,
  ...)

.. include:: _include/intro.rst

Download the latest `hrmpf <https://github.com/leahneukirchen/hrmpf/releases>`_, write it to USB drive and boot your
system in EFI mode. You can confirm you've booted in EFI mode by running ``efibootmgr``. 

.. include:: _include/zfs-prep.rst

ZFS pool creation
-----------------

Create the zpool
~~~~~~~~~~~~~~~~

.. tabs::

    .. group-tab:: Encrypted

      .. code-block::

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

      .. include:: _include/enc-pool-creation-notes.rst

    .. group-tab:: Unencrypted

      .. code-block::

        zpool create -f -o ashift=12 \
         -O compression=lz4 \
         -O acltype=posixacl \
         -O xattr=sa \
         -O relatime=on \
         -o autotrim=on \
         -m none zroot /dev/sda

.. include:: _include/create-filesystems.rst

.. include:: _include/install.rst

.. include:: _include/zfs-config.rst

Install and configure ZFSBootMenu
---------------------------------

Create an EFI partition on ``/dev/sdb``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. parsed-literal::

  bash-5.0# **gdisk /dev/sdb**
  GPT fdisk (gdisk) version 1.0.4

  Partition table scan:
    MBR: not present
    BSD: not present
    APM: not present
    GPT: not present

  Creating new GPT entries in memory.

  Command (? for help): **o**
  This option deletes all partitions and creates a new protective MBR.
  Proceed? (Y/N): **y**

  Command (? for help): **n**
  Partition number (1-128, default 1): **1**
  First sector (34-1000215182, default = 2048) or {+-}size{KMGTP}: **2048**
  Last sector (2048-1000215182, default = 1000215182) or {+-}size{KMGTP}: **+512M**
  Current type is 'Linux filesystem'
  Hex code or GUID (L to show codes, Enter = 8300): **EF00**
  Changed type of partition to 'EFI System'

  Command (? for help): **w**

  Final checks complete. About to write GPT data. THIS WILL OVERWRITE EXISTING
  PARTITIONS!!

  Do you want to proceed? (Y/N): **y**
  OK; writing new GUID partition table (GPT) to /dev/sdb.
  The operation has completed successfully.

Create a vfat filesystem
~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  mkfs.vfat -F32 /dev/sdb1

Create an fstab entry and mount
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  cat << EOF >> /etc/fstab
  $( blkid | grep /dev/sdb1 | cut -d ' ' -f 2 ) /boot/efi vfat defaults,noauto 0 0
  EOF
  mkdir /boot/efi
  mount /boot/efi

.. include:: _include/zbm-setup.rst

.. include:: _include/zbm-setup-efi.rst

.. include:: _include/gen-initramfs.rst

.. include:: _include/refind.rst

.. include:: _include/cleanup.rst

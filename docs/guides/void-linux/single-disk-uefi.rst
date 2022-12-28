Single-disk UEFI
================

.. contents:: Contents
  :depth: 2
  :local:
  :backlinks: none

This guide can be used to install Void onto a single disk with with or without ZFS encryption. 

It assumes the following:

* Your system uses UEFI to boot
* Your system is x86_64
* You will use ``glibc`` as your system libc.
* ``/dev/sda`` is the onboard SSD, used for both ZFS and EFI
* You're mildly comfortable with ZFS, EFI and discovering system facts on your own (``lsblk``, ``dmesg``, ``gdisk``,
  ...)

.. include:: _include/intro.rst

Download the latest `hrmpf <https://github.com/leahneukirchen/hrmpf/releases>`_, write it to USB drive and boot your
system in EFI mode. You can confirm you've booted in EFI mode by running ``efibootmgr``.

.. include:: _include/zfs-prep.rst

SSD prep work
-------------

Create an EFI partition on ``/dev/sda``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. parsed-literal::

  bash-5.0# **gdisk /dev/sda**
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

  Command (? for help): **n**
  Partition number (2-128, default 2): **2**
  First sector (34-1000215182, default = 1050624) or {+-}size{KMGTP}: **1050624**
  Last sector (1050624-1000215182, default = 1000215182) or {+-}size{KMGTP}: **-1M**
  Current type is 'Linux filesystem'
  Hex code or GUID (L to show codes, Enter = 8300): **BF00**
  Changed type of partition to 'Linux filesystem'

  Command (? for help): **w**

  Final checks complete. About to write GPT data. THIS WILL OVERWRITE EXISTING
  PARTITIONS!!

  Do you want to proceed? (Y/N): **y**
  OK; writing new GUID partition table (GPT) to /dev/sda.
  The operation has completed successfully.

.. include:: _include/pool-creation-non-detached.rst

.. include:: _include/create-filesystems.rst

.. include:: _include/install.rst

.. include:: _include/zfs-config.rst

Install and configure ZFSBootMenu
---------------------------------

Create a ``vfat`` filesystem
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  mkfs.vfat -F32 /dev/sda1

Create an fstab entry and mount
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  cat << EOF >> /etc/fstab
  $( blkid | grep /dev/sda1 | cut -d ' ' -f 2 ) /boot/efi vfat defaults 0 0
  EOF
  mkdir /boot/efi
  mount /boot/efi

.. include:: _include/zbm-setup.rst

.. include:: _include/zbm-setup-efi.rst

.. include:: _include/gen-initramfs.rst

.. include:: _include/refind.rst

.. include:: _include/cleanup.rst

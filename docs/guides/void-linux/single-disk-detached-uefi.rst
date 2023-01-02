Single-disk detached UEFI
=========================

.. |boot_disk| replace:: /dev/sdb
.. |boot_part_no| replace:: 1

.. |pool_disk| replace:: /dev/sda
.. |pool_part_no| replace:: 1 

.. |distribution| replace:: void

.. |zbmkcl| replace:: quiet

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

.. include:: ../_include/intro.rst

Download the latest `hrmpf <https://github.com/leahneukirchen/hrmpf/releases>`_, write it to USB drive and boot your
system in EFI mode.

.. include:: ../_include/efi-boot-check.rst

.. include:: _include/zfs-prep.rst

.. include:: ../_include/define-env.rst

.. include:: ../_include/ssd-prep.rst

.. include:: ../_include/pool-creation.rst

.. include:: ../_include/create-filesystems.rst

.. include:: _include/void-install.rst

.. include:: _include/zfs-config.rst

.. include:: ../_include/zbm-setup.rst

.. include:: ../_include/setup-esp.rst

.. include:: _include/zbm-install.rst

.. include:: _include/efi-boot-method.rst

.. include:: ../_include/cleanup.rst

Bullseye Single-disk UEFI
=========================

.. |esp_disk| replace:: /dev/sda
.. |esp_part_no| replace:: 1
.. |esp_part_full| replace:: /dev/sda1

.. |pool_disk| replace:: /dev/sda
.. |pool_part_no| replace:: 2
.. |pool_part_full| replace:: /dev/sda2

.. |distribution| replace:: debian

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

.. include:: _include/early-prep.rst

.. include:: ../_include/ssd-prep-erase.rst

.. include:: ../_include/ssd-prep-esp.rst

.. include:: ../_include/pool-creation.rst

.. include:: ../_include/create-filesystems.rst

.. include:: _include/debian-install.rst

.. include:: _include/zfs-config.rst

.. include:: ../_include/zbm-setup.rst

.. include:: ../_include/setup-esp.rst

.. include:: _include/zbm-install.rst

.. include:: _include/efi-boot-method.rst

.. include:: ../_include/cleanup.rst

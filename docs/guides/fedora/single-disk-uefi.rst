Workstation 37 Single-disk UEFI
===============================

.. |boot_disk| replace:: /dev/sda
.. |boot_part_no| replace:: 1

.. |pool_disk| replace:: /dev/sda
.. |pool_part_no| replace:: 2

.. |distribution| replace:: fedora

.. |zbmkcl| replace:: quiet rhgb

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

Download `Fedora Workstation Live <https://download.fedoraproject.org/pub/fedora/linux/releases/37/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-37-1.7.iso>`_
, write it to a USB drive and boot your system in EFI mode.

.. include:: ../_include/efi-boot-check.rst

.. include:: _include/early-prep.rst

.. include:: ../_include/define-env.rst

.. include:: ../_include/ssd-prep.rst

.. include:: ../_include/pool-creation.rst

.. include:: ../_include/create-filesystems.rst

.. include:: _include/distro-install.rst

.. include:: _include/zfs-config.rst

.. include:: ../_include/zbm-setup.rst

.. include:: ../_include/setup-esp.rst

.. include:: _include/zbm-install.rst

.. include:: _include/efi-boot-method.rst

.. include:: _include/reset-resolv.rst

.. include:: ../_include/cleanup.rst

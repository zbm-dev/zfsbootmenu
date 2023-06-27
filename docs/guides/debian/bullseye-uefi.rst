Bullseye (11) UEFI
==================

.. |distribution| replace:: debian

.. contents:: Contents
  :depth: 2
  :local:
  :backlinks: none

This guide can be used to install Debian onto a single disk with or without ZFS encryption.

It assumes the following:

* Your system uses UEFI to boot
* Your system is x86_64
* You're mildly comfortable with ZFS, EFI and discovering system facts on your own (``lsblk``, ``dmesg``, ``gdisk``, ...)

Download the latest `Debian Bullseye (11) Live image <https://cdimage.debian.org/mirror/cdimage/archive/11.7.0-live/amd64/iso-hybrid/>`_, write it to a USB drive and
boot your system in EFI mode.

.. include:: ../_include/efi-boot-check.rst

.. include:: _include/bullseye/live-environment.rst

.. include:: ../_include/define-env.rst

.. include:: ../_include/disk-preparation.rst

.. include:: ../_include/pool-creation.rst

.. include:: ../_include/create-filesystems.rst

.. include:: ../_include/update-devices.rst

.. include:: _include/bullseye/distro-install.rst

.. include:: _include/zfs-config.rst

.. include:: ../_include/zbm-setup.rst

.. include:: ../_include/setup-esp.rst

.. include:: _include/zbm-install.rst

.. include:: _include/efi-boot-method.rst

.. include:: ../_include/cleanup.rst

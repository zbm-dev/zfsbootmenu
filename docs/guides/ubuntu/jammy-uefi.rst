Jammy (22.04) UEFI
==================

.. |distribution| replace:: ubuntu

.. contents:: Contents
  :depth: 2
  :local:
  :backlinks: none

This guide can be used to install Ubuntu onto a single disk with or without ZFS encryption.

The end result will be a pristine Ubuntu install with no GUI or anything other than the base system. You'll be able to
install `ubuntu-desktop`, `ubuntu-server-minimal` or whatever takes your fancy afterwards.

It assumes the following:

* Your system uses UEFI to boot
* Your system is x86_64
* You're mildly comfortable with ZFS, EFI and discovering system facts on your own (``lsblk``, ``dmesg``, ``gdisk``, ...)

Download the latest `Ubuntu Desktop Jammy (22.04) Live image <https://www.releases.ubuntu.com/22.04/>`_, write it to a USB drive and
boot your system in EFI mode. You can use the server installation media if you want, although instructions are provided for
installation using the desktop installer live session.

.. include:: _include/live-environment.rst

.. include:: ../_include/define-env.rst

.. include:: ../_include/disk-preparation.rst

.. include:: ../_include/pool-creation.rst

.. include:: ../_include/create-filesystems.rst

.. include:: ../_include/update-devices.rst

.. include:: _include/distro-install-jammy.rst

.. include:: _include/zfs-config.rst

.. include:: ../_include/zbm-setup.rst

.. include:: ../_include/setup-esp.rst

.. include:: _include/zbm-install.rst

.. include:: _include/efi-boot-method.rst

.. include:: ../_include/cleanup.rst

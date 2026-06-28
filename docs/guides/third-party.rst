Third-Party Resources
=====================

The following links are not hosted by ZFSBootMenu, but may provide useful information.

Arch Linux
----------

* `Arch User Repository: ZFSBootMenu <https://aur.archlinux.org/packages/zfsbootmenu>`_
* `Arch User Repository: ZFSBootMenu EFI binaries <https://aur.archlinux.org/packages/zfsbootmenu-efi-bin>`_

Gentoo
------

* `Gentoo Wiki: root on ZFS <https://wiki.gentoo.org/wiki/ZFS/rootfs>`_

NixOS
-----

* `Sirn Thanabulpong: ZFSBootMenu on NixOS <https://grid.in.th/2024/12/zfsbootmenu_on_nixos/>`_

OpenWrt
-------

* `zbm-openwrt-clevis <https://github.com/rdmitry0911/zbm-openwrt-clevis>`_ - an OpenWrt-based boot runtime that gates
  unattended boot with TPM2/Clevis PCR policy, uses ZFSBootMenu to select and kexec a boot environment, and falls back
  to authenticated OpenWrt login for manual reseal when measurements change.

Generate the initial ZFSBootMenu initramfs
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: none

  xbps-reconfigure -f zfsbootmenu
  zfsbootmenu: configuring ...
  Creating ZFS Boot Menu 0.8.1_1, with vmlinuz 5.4.15_1
  Found 0 existing images, allowed to have a total of 3
  Created /boot/efi/EFI/void/vmlinuz-0.8.1_1, /boot/efi/EFI/void/initramfs-0.8.1_1.img

Fetch a prebuilt ZFSBootMenu EFI executable, saving it to the EFI system partition:

.. code-block::

  mkdir -p /boot/efi/EFI/zbm
  curl -o /boot/efi/EFI/zbm/vmlinuz.EFI -L https://get.zfsbootmenu.org/efi

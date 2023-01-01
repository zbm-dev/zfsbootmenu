Fetch a prebuilt ZFSBootMenu EFI executable, saving it to the EFI system partition:

.. code-block::

  mkdir -p /boot/efi/EFI/ZBM
  curl -o /boot/efi/EFI/ZBM/VMLINUZ.EFI -L https://get.zfsbootmenu.org/efi
  cp /boot/efi/EFI/ZBM/VMLINUZ.EFI /boot/efi/EFI/ZBM/VMLINUZ-BACKUP.EFI

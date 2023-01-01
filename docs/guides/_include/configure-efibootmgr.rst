.. code-block:: bash

  efibootmgr -c -d "$BOOT_DISK" -p "$BOOT_PART" \
    -L "ZFSBootMenu (Backup)" \
    -l \\EFI\\ZBM\\VMLINUZ-BACKUP.EFI

  efibootmgr -c -d "$BOOT_DISK" -p "$BOOT_PART" \
    -L "ZFSBootMenu" \
    -l \\EFI\\ZBM\\VMLINUZ.EFI
  
.. note::

  Some systems are known to have issues with EFI entries and may not boot correctly. If
  this is the case, move **/boot/efi/EFI/zbm/vmlinuz.EFI** to **/boot/efi/EFI/BOOT/BOOTX64.EFI**.

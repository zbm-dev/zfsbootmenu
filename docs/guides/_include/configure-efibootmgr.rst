.. parsed-literal::

  efibootmgr -c -d |esp_disk| -p |esp_part_no| -L "ZFSBootMenu" -l \\EFI\\ZBM\\VMLINUZ.EFI
  efibootmgr -c -d |esp_disk| -p |esp_part_no| -L "ZFSBootMenu (Backup)" -l \\EFI\\ZBM\\VMLINUZ-BACKUP.EFI

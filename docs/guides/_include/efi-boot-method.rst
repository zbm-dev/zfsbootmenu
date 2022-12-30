Configure EFI boot entries
~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Direct

    .. parsed-literal::

      xbps-install -S efibootmgr
      efibootmgr -c -d |esp_disk| -p |esp_part_no| -L "ZFSBootMenu" -l \\EFI\\ZBM\\VMLINUZ.EFI
      efibootmgr -c -d |esp_disk| -p |esp_part_no| -L "ZFSBootMenu (Backup)" -l \\EFI\\ZBM\\VMLINUZ-BACKUP.EFI

  .. group-tab:: rEFInd

    .. parsed-literal::

      xbps-install -S refind
      refind-install
      rm /boot/refind_linux.conf

      cat << EOF > /boot/efi/EFI/zbm/refind_linux.conf
      "Boot default"  "quiet loglevel=0 zbm.skip"
      "Boot to menu"  "quiet loglevel=0 zbm.show"
      EOF

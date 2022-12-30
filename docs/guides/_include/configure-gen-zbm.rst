Configure :doc:`generate-zbm(5) </man/generate-zbm.5>` by ensuring that the following keys appear in
``/etc/zfsbootmenu/config.yaml``:

.. code-block:: yaml

   Global:
     ManageImages: true
     BootMountPoint: /boot/efi
   EFI:
     ImageDir: /boot/efi/EFI/zbm
     Versions: false
     Enabled: true

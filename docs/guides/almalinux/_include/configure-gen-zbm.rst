Configure :doc:`generate-zbm(5) </man/generate-zbm.5>` by ensuring that the following keys appear in
``/etc/zfsbootmenu/config.yaml``:

.. code-block:: yaml

  Global:
    ManageImages: true
    BootMountPoint: /boot/efi
  Components:
     Enabled: false
     Versions: false
  EFI:
    ImageDir: /boot/efi/EFI/zbm
    Enabled: true
  Kernel:
    CommandLine: quiet loglevel=0
    Version: "*.x86_64"

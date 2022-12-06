Enable ZFSBootMenu image creation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Edit ``/etc/zfsbootmenu/config.yaml`` and set:

* ``ManageImages: true`` under the ``Global`` section
* ``Versions: 3`` and ``Enabled: true`` under the ``Components`` section

See :doc:`generate-zbm(5) </man/generate-zbm.5>` for more details.

Sample /etc/zfsbootmenu/config.yaml
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: yaml

  Global:
    ManageImages: true
    BootMountPoint: /boot/efi
    DracutConfDir: /etc/zfsbootmenu/dracut.conf.d
  Components:
    ImageDir: /boot/efi/EFI/void
    Versions: 3
    Enabled: true
    syslinux:
      Config: /boot/syslinux/syslinux.cfg
      Enabled: false
  EFI:
    ImageDir: /boot/efi/EFI/void
    Versions: 2
    Enabled: false
  Kernel:
    CommandLine: quiet loglevel=0

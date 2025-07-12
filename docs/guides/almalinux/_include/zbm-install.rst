Install ZFSBootMenu
~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Prebuilt

    .. include:: ../_include/zbm-install-prebuilt.rst

  .. group-tab:: Source

    .. include:: _include/zbm-install-deps.rst

    .. include:: ../_include/zbm-install-source.rst

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
            ImageDir: /boot/efi/EFI/ZBM
            Enabled: true
        Kernel:
            CommandLine: quiet loglevel=0
            Version: "*.x86_64"


    .. include:: ../_include/gen-initramfs.rst

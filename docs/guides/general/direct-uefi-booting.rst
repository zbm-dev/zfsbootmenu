UEFI Booting without an intermediate boot manager
=================================================

On most UEFI systems, booting ZFSBootMenu without the use of an intermediate boot manager like rEFInd is possible. Linux
kernels typically include an EFI stub and can be invoked as UEFI executables directly by the firmware. Unfortunately,
while some UEFI implementations allow passing of command-line arguments to the UEFI kernel, others (from Dell, for
example) seem to ignore all configured command-line arguments, making it impossible to specify needed options (such as
the path to the ZFSBootMenu initramfs). Even those implementations that do respect configured arguments may provide no
firmware interface to alter these arguments, which means booting a backup ZFSBootMenu image may not be possible if it
wasn't configured in advance from a Linux installation.

These limitations are easily avoided if ZFSBootMenu is packaged as a *bundled UEFI executable* that encapsulates the 
Linux kernel, ZFSBootMenu initramfs and all needed command-line arguments. Dracut facilitates the creation of a bundled
UEFI executable, and the ``generate-zbm`` script exposes this capability.

Creation of a Bundled UEFI Executable
-------------------------------------

The ``EFI`` section of the ZFSBootMenu :doc:`config.yaml </man/generate-zbm.5>`
governs the creation of bundled UEFI executables. The default configuration disables this option; to enable it, set
``EFI.Enabled: true``:

.. code-block:: yaml

  EFI:
    Enabled: true

The remaining keys in the ``EFI`` section allow control over where and how UEFI bundles are created:

* ``ImageDir`` is the location where the bundle will be written, and should generally be a subdirectory of the ``EFI``
  subdirectory of your EFI system partition. The default, ``/boot/efi/EFI/void``, is fine if the ESP is mounted at
  ``/boot/efi`` (and you are either running Void Linux or don't care if the directory name matches your distribution
  name).
* ``Versions`` controls whether UEFI bundles include a version and revision number in their name and, if so, how many
  prior versioned executables are retained. Because the firmware is not automatically reconfigured to boot the latest
  version after runs of ``generate-zbm``, it is probably best to disabling ``Versions`` by setting its value to ``false``
  or ``0``. See the :ref:`description of this key in manual page <config-components>` for more details about its
  behavior. Even when versioning is disabled, ``generate-zbm`` still makes a backup of your existing boot image by
  replacing its ``.EFI`` extension with ``-backup.EFI`` to provide a fallback.
* ``Stub`` specifies the location of the UEFI stub loader required when creating a bundled executable. Both ``gummiboot``
  and its descendant ``systemd-boot`` provide stub loaders; ``gummiboot``, for example, tends to store the loader at
  ``/usr/lib/gummiboot/linuxx64.efi.stub``. If this key is omitted (as it is by default), ``dracut`` will attempt to
  find either the ``systemd-boot`` or ``gummiboot`` version at their expected locations. This key is useful when
  automatic detection fails.

In addition, two options in the ``Kernel`` section of the configuration file are used during bundle creation:

* ``Prefix`` provides the base name for the output bundle file. If this is omitted, the base name will be derived from
  the name of the kernel used to create the image; for example, the kernel ``/boot/vmlinuz-<version>`` will produce a
  bundle called ``vmlinuz.EFI`` in the configured ``ImageDir``, while the kernel ``/boot/vmlinuz-lts-<version>`` will
  produce a bundle called ``vmlinuz-lts.EFI``.
* ``CommandLine`` provides the command-line arguments that will be encoded in the bundle and passed to the kernel during
  boot. The ``dracut`` configuration option ``kernel_cmdline`` also provides a mechanism for encoding the kernel
  command-line; if the ZFSBootMenu configuration specifies ``Kernel.CommandLine`` and the ``dracut`` configuration for
  ZFSBootMenu specifies ``kernel_cmdline``, the two values will be concatenated.

After adjusting the configuration options as desired, run ``generate-zbm`` and a bundled UEFI executable will be created
in ``EFI.ImageDir``.

Booting the Bundled Executable
------------------------------

The `efibootmgr <https://github.com/rhinstaller/efibootmgr>`_ utility provides a means to configure your firmware to
boot the bundled executable. For example::

  efibootmgr -c -d /dev/sda -p 1 -L "ZFSBootMenu" -l \\EFI\\VOID\\VMLINUZ.EFI

will create a new entry that will boot the executable written to ``/boot/efi/EFI/void/vmlinuz.EFI`` if your EFI system
partition is ``/dev/sda1`` and is mounted at ``/boot/efi``. (Remember that the EFI system partition should be a FAT
volume, so the path separators are backslashes and paths should be case-insensitive.) For good measure, create an
alternative entry that points at the backup image::

  efibootmgr -c -d /dev/sda -p 1 -L "ZFSBootMenu (Backup)" -l \\EFI\\VOID\\VMLINUZ-BACKUP.EFI

The firmware should provide some means to select between these alternatives.

It is also generally possible to configure the boot sequence from your firmware setup interface. Simply find and select
the path to the bundled EFI executable from this interface.

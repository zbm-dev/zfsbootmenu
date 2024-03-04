Portable ZFSBootMenu
====================

UEFI makes it easy to deploy ZFSBootMenu without a local installation. Most
UEFI systems will search for and run an EFI executable at the path
``/EFI/BOOT/BOOTX64.EFI`` on a FAT-formatted `EFI System Partition`_
located on any disk that the firmware is told to boot. This executable can be a
standard ZFSBootMenu release image or a custom, locally generated image. Almost
any modern system can be made to launch a ZFSBootMenu instance just by
inserting and booting from a minimally configured USB drive.

.. _EFI System Partition: https://en.wikipedia.org/wiki/EFI_system_partition

Procedure
---------

1. On a USB drive, create a GPT header.

2. Create an `EFI system partition`_ on the drive. The partition should be at
   least 100 MB.

   * With `gdisk <https://man.voidlinux.org/gdisk.8>`_, this is accomplished by
     setting the parition type to ``EF00``.

   * With `parted <https://man.voidlinux.org/parted.8>`_, this is accomplished
     by setting the ``boot`` flag on the partition.

3. Format the partition as FAT.

4. Fetch a copy of the ZFSBootMenu release image:

   .. code-block:: sh

     curl -LJO https://get.zfsbootmenu.org/efi/recovery

5. Save the resulting download as ``EFI/BOOT/BOOTX64.EFI`` within the EFI
   system partiton.

6. Tell your system to boot from the USB drive.

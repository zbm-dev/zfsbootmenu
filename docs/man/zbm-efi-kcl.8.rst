===========
zbm-efi-kcl
===========

SYNOPSIS
========

**zbm-efi-kcl** [-f <kcl-file>] [-k <kcl-text>] [-o <output>] -e <input>

DESCRIPTION
===========

The **zbm-efi-kcl** utility allows review and manipulation of the embedded kernel command line value present in ZFSBootMenu EFI binaries. This value is used by most UEFI firmware implementations and bootloaders.

OPTIONS
=======

**-e** *input*

  Define the EFI binary upon which to operate. This option is required.

**-f** *kcl-file*

  Replace the embedded kernel command line with the contents of the file. This is primarily intended for automated changes to the EFI binary.

**-k** *kcl-text*

  Replace the kernel command line with the quoted argument. Ensure proper shell quoting behavior is respected here.

**-o** *output*

  After changing the embedded kernel command line, store the new EFI binary under a new file name. The input EFI binary is left unchanged.

If neither **-f** or **-k** are provided, the command line from the input EFI binary will be opened in ``$EDITOR``.

EXAMPLES
========

Perform an in-place edit of the commandline in the release EFI binary::

  zbm-efi-kcl -e /boot/efi/EFI/BOOT/zfsbootmenu.EFI

Perform an edit and store the change in a new file::

  zbm-efi-kcl -e /boot/efi/EFI/boot/zfsbootmenu.EFI -o /boot/efi/EFI/boot/zfsbootmenu-testing.EFI

SEE ALSO
========

:doc:`zfsbootmenu(7) </man/zfsbootmenu.7>`

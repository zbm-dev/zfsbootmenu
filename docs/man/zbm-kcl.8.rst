=======
zbm-kcl
=======

SYNOPSIS
========

**zbm-kcl** [OPTION]... [FILESYSTEM|EFI_EXECUTABLE]

DESCRIPTION
===========

The **zbm-kcl** utility allows review and manipulation of the *org.zfsbootmenu:commandline* property on ZFS filesystems
or the *.cmdline* section encoded within ZFSBootMenu EFI executables. ZFSBootMenu reads the property
*org.zfsbootmenu:commandline*, as set or inherited on each environment that it recognizes, to set the command line for
the kernel that it boots. The ZFSBootMenu EFI executable reads its own *.cmdline* section to parse options that control
the behavior of ZFSBootMenu itself.

The final argument is treated as a ZFS filesystem as long as one exists with the specified name. If a matching
filesystem cannot be found, the argument is treated as an EFI executable. To force **zbm-kcl** to treat the final
argument as a relative path to an EFI executable even when a ZFS filesystem exists with the same name, prefix the path
with *./*.

When neither a filesystem nor an EFI executable is specified, **zbm-kcl** will attempt to determine the root filesystem
and operate on that.

If an EFI executable of *-* is specified, *stdin* will be read as an EFI executable.

With no options specified, **zbm-kcl** will print the current value of *org.zfsbootmenu:commandline* of the selected
filesystem or the *.cmdline* section of the named EFI executable and exit.

OPTIONS
=======

**-a** *argument*

  Append the value of *argument* to the kernel command line. The value of *argument* can be a simple variable name for
  Boolean arguments or may take the form *var=value* to provide a non-Boolean value. Multiple command-line arguments may
  be accumulated into a single *argument*. If the value of any variable value contains spaces, it should be surrounded
  by double quotes. In that case, surround the entire argument in single quotes to ensure that the double quotes are
  recorded in the property::

    zbm-kcl -a 'variable="some argument with spaces"'

  This argument may be repeated any number of times.

**-r** *argument*

  Remove *argument* from the kernel command line. The value of *argument* can be a simple variable name, in which case
  all arguments of the form *argument* or *argument=<arbitrary-value>* will be stripped. Alternatively, a specific
  argument may be selected by specifying *argument=<specific-value>*.

  This argument may be repeated any number of times.

  .. note::

    All removal options are processed *before* any append options are processed, making it possible to replace an
    existing argument by combining removal and append options into a single invocation of **zbm-kcl**.

**-e**

  Open the contents of the command-line in an interactive editor. If the environment defines *$EDITOR*, that will be
  used; otherwise, **vi** will be used by default. After making changes as desired, overwrite the (temporary) file that
  was opened and quit the editor. The contents of the saved file will be written by **zbm-kcl** as the new command line.

**-d**

  Delete the command-line property.

  For a ZFS filesystem, this is accomplished by calling

  .. code-block::

    zfs inherit org.zfsbootmenu:commandline <filesystem>

  to allow the boot environment to inherit any command-line property that may be defined by some parent.

  For a ZFSBootMenu EFI executable, the *.cmdline* section will be stripped.

**-o** *destination*

  Save the modified command line to *destination* rather than back to the original source. When the source is a ZFS
  filesystem, the destination must also be a valid ZFS filesystem. When the source is an EFI executable, the destination
  will be treated as a file; a special EFI *destination* of *-* will cause the file to be written to *stdout*.

EXAMPLES
========

Change the *loglevel* value on the currently booted environment by removing any existing value from the command line and
appending the desired argument::

  zbm-kcl -a loglevel=7 -r loglevel

Delete the entire command line from the *zroot/ROOT/void* boot environment, allowing it to inherit a command line set at
*zroot* or *zroot/ROOT* if either of these defines a value::

  zbm-kcl -d zroot/ROOT/void

Allow interactive editing of the command line on the *zroot/ROOT* filesystem, but save the resulting changes to
*zroot/ROOT/void* rather than back to *zroot/ROOT*::

  zbm-kcl -e -o zroot/ROOT/void zroot/ROOT

Review the current command line embedded in the EFI file */boot/efi/EFI/zfsbootmenu/zfsbootmenu.EFI*::

  zbm-kcl /boot/efi/EFI/zfsbootmenu/zfsbootmenu.EFI

Fetch the official ZFSBootMenu release EFI executable, customizing the menu timeout and saving the result to
*zfsbootmenu-custom.EFI*::

  curl -L https://get.zfsbootmenu.org/efi | \
    zbm-kcl -a zbm.timeout=15 -r zbm.timeout -o zfsbootmenu-slow.EFI -

SEE ALSO
========

:doc:`zfsbootmenu(7) </man/zfsbootmenu.7>`

..
  vim: softtabstop=2 shiftwidth=2 textwidth=120

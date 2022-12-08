=======
zbm-kcl
=======

SYNOPSIS
========

**zbm-kcl** [OPTION]... [FILESYSTEM]

DESCRIPTION
===========

The **zbm-kcl** utility allows review and manipulation of the *org.zfsbootmenu:commandline* property on ZFS filesystems. ZFSBootMenu reads this property, as set or inherited on each environment that it recognizes, to set the command line for the kernel that it boots.

When a filesystem is not specified, **zbm-kcl** will attempt to determine the root filesystem and operate on that.

With no options specified, **zbm-kcl** will print the current value of *org.zfsbootmenu:commandline* on the selected filesystem and exit.

OPTIONS
=======

**-a** *argument*

  Append the value of *argument* to the kernel command line. The value of *argument* can be a simple variable name for Boolean arguments or may take the form *var=value* to provide a non-Boolean value. If *value* contains spaces, it may be surrounded by double quotes. In that case, surround the argument in single quotes to ensure that the double quotes are recorded in the property::

    zbm-kcl -a 'variable="some argument with spaces"'

  This argument may be repeated any number of times.

**-r** *argument*

  Remove *argument* from the kernel command line. The value of *argument* can be a simple variable name, in which case all arguments of the form *argument* or *argument=<arbitrary-value>* will be stripped. Alternatively, a specific argument may be selected by specifying *argument=<specific-value>*.

  This argument may be repeated any number of times.

  .. note::

    All removal options are processed *before* any append options are processed, making it possible to replace an existing argument by combining removal and append options into a single invocation of **zbm-kcl**.

**-e**

  Open the contents of the command-line property in an interactive editor. If the environment defines *$EDITOR*, that will be used; otherwise, **vi** will be used by default. After making changes as desired, overwrite the (temporary) file that was opened and quit the editor. If the contents of the command-line property appear to have changed, **zbm-kcl** will apply those changes.

**-d**

  Delete the command-line property by calling

  .. code-block::

    zfs inherit org.zfsbootmenu:commandline <filesystem>

  This allows the boot environment to inherit any command-line property that may be defined by some parent.

**-v**

  Increase the verbosity of **zbm-kcl** as it operates. This may be specified up to three times.

EXAMPLES
========

Change the *loglevel* value on the currently booted environment by removing any existing value from the command line and appending the desired argument::

  zbm-kcl -a loglevel=7 -r loglevel

Delete the entire command line from the *zroot/ROOT/void* boot environment, allowing it to inherit a command line set at *zroot* or *zroot/ROOT* if either of these defines a value::

  zbm-kcl -d zroot/ROOT/void

Allow interactive editing of the command line on the *zroot/ROOT* filesystem::

  zbm-kcl -e zroot/ROOT

SEE ALSO
========

:doc:`zfsbootmenu(7) </man/zfsbootmenu.7>`

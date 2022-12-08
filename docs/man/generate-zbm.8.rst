============
generate-zbm
============

.. KEEP IN SYNC WITH bin/generate-zbm

.. only:: html

  .. toctree::
    :hidden:

    generate-zbm.5

SYNOPSIS
========

**generate-zbm** [options]

OPTIONS
=======

Where noted, command-line options supersede options in the :doc:`generate-zbm(5) </man/generate-zbm.5>` configuration file.

**--version|-v** *zbm-version*

  Override the ZFSBootMenu version in output files; supersedes *Global.Version*

**--kernel|-k** *kernel-path*

  Manually specify a specific kernel; supersedes *Kernel.Path*

**--kver|-K** *kernel-version*

  Manually specify a specific kernel version; supersedes *Kernel.Version*

**--prefix|-p** *image-prefix*

  Manually specify the output image prefix; supersedes *Kernel.Prefix*

**--initcpio|-i**

  Force the use of mkinitcpio instead of dracut.

**--no-initcpio|-i**

  Force the use of dracut instead of mkinitcpio.

**--confd|-C** *config-path*

  Specify initramfs configuration path

  * For dracut: supersedes *Global.DracutConfDir*

  * For mkinitcpio: supersedes *Global.InitCPIOConfig*

**--hookd|-H** *hookd-path*

  Specify mkinitcpio hook directory; supersedes *Global.InitCPIOHookDirs*

  May be specified more than once. Ignored when using dracut.

**--cmdline|-l** *options*

  Override the kernel command line; supersedes *Kernel.CommandLine*

**--bootdir|-b** *boot-path*

  Specify the path to search for kernel files; default: */boot*

**--config|-c** *conf-file*

  Specify the path to a configuration file; default: */etc/zfsbootmenu/config.yaml*

**--enable**

  Set the *Global.ManageImages* option to true, enabling image generation.

**--disable**

  Set the *Global.ManageImages* option to false, disabling image generation.

**--debug|-d**

  Enable debug output

**--showver|-V**

  Print ZFSBootMenu version and quit.

SEE ALSO
========

:doc:`generate-zbm(5) </man/generate-zbm.5>` :doc:`zfsbootmenu(7) </man/zfsbootmenu.7>`

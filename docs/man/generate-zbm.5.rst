===========
config.yaml
===========

SYNOPSIS
========

**/etc/zfsbootmenu/config.yaml**

DESCRIPTION
===========

The YAML file ``/etc/zfsbootmenu/config.yaml`` controls the generation of ZFSBootMenu images by :doc:`generate-zbm(8) </man/generate-zbm.8>`.

SECTIONS
========

The configuration is divided into several logical sections as keys of a YAML map. The value of each section is itself a YAML map.

Global
------

**ManageImages**

  This must be set to *true* before **generate-zbm** will attempt to perform any action (e.g., image creation or pruning old files).

**InitCPIO**

  Set to *true* to use **mkinitcpio** instead of **dracut** to create ZFSBootMenu images.

**DracutConfDir**

  The path of the dracut configuration directory for ZFSBootMenu. This **MUST NOT** be the same location as the system *dracut.conf.d*, as the configuration files there interfere with the creation of the ZFSBootMenu initramfs. If unspecified, a default value of */etc/zfsbootmenu/dracut.conf.d* is assumed. This value is ignored when *Global.InitCPIO* is *true*.

**InitCPIOConfig**

  The path to a mkinitcpio configuration file for ZFSBootMenu. The *zfsbootmenu* hook will be forcefully added when **generate-zbm** invokes **mkinitcpio** using a command-line argument and does not need to be specified in the *HOOKS* array in the configuration file. This value is ignored when *Global.InitCPIO* is not *true*.

**InitCPIOHookDirs**

  A single path or an array of paths to **mkinitcpio** hook directories. When specifying a custom directory for the *zfsbootmenu* hook, it is generally required to also specify the default location as well. This option is ignored when *Global.InitCPIO* is not *true*.

**BootMountPoint**

  In general, this should be the location of your EFI System Partition. **generate-zbm** will ensure that this is mounted when images are created and, if **generate-zbm** does the mounting, will unmount this filesystem on exit. When this parameter is not specified, **generate-zbm** will not verify or attempt to mount any filesystems.

**Version**

  A specific ZFSBootMenu version string to use in versioned output images. In the string, the value *%{current}* will be replaced with the release version of ZFSBootMenu. The default value is simply *%{current}*.

**DracutFlags**

  An array of additional arguments that will be passed to **dracut** when generating an initramfs. This option is ignored when *Global.InitCPIO* is *true*.

**InitCPIOFlags**

  An array of additional arguments that will be passed to **mkinitcpio** when generating an initramfs. This option is ignored when *Global.InitCPIO* is not *true*.

**PreHooksDir**

  The path of the directory containing executables that should be executed after *BootMountPoint* has been mounted. Files in this directory should be **+x**, and are executed in the order returned by a shell glob. The exit code of each hook is ignored.

**PostHooksDir**

  The path of the directory containing executables that should be executed after all images have been created and any file pruning has taken place. Files in this directory should be **+x**, and are executed in the order returned by a shell glob. The exit code of each hook is ignored.


Kernel
------

**CommandLine**

  If you're making a unified EFI file, this is the command line passed to the boot image.

**Path**

  The full path to a specific kernel to use when making the boot images. If not specified, **generate-zbm** will try to pick a reasonable kernel.

**Version**

  A specific kernel version to use, or a glob used to match possible kernel versions. The value *%{current}* will be replaced with the output of ``uname -r``. For globs, the highest version matching the glob will be selected. If not set, **generate-zbm** will try to parse the path of the selected kernel filename for a version.

**Prefix**

  The prefix to use for the names of ZFSBootMenu images. By default, the prefix is extracted from the input kernel name.

.. _config-components:

Components
----------

**Enabled**

  When *true*, **generate-zbm** will create separate ZFSBootMenu kernel and initramfs images. The default value is *false*.

**ImageDir**

  The destination directory for separate initramfs and kernel images.

**Versions**

  When *false* or *0*, image versioning will be disabled; **generate-zbm** will not use its *Global.Version* parameter to name outputs, and will keep exactly one backup copy of any image it would overwrite.

  When *true* (which behaves as *1*) or any positive integer, **generate-zbm** will append the value of *Global.Version* to every image it produces, followed by a revision as *_$revision*. **generate-zbm** will save *Components.Versions* revisions of all images with versions matching the current value of *Global.Version*. In addition, **generate-zbm** will save the highest revision of the most recent *Components.Versions* image versions distinct from *Global.Version*.

EFI
---

**Enabled**

  When *true*, **generate-zbm** will create unified UEFI bundles. The default value is *false*.

**ImageDir**

  The destination directory for unified EFI files.

**Versions**

  Behaves similarly to *Components.Versions*, but acts on files matching the UEFI bundle naming scheme.

**Stub**

  The path to the EFI stub loader used to boot the unified bundle. If not set, a default of ``/usr/lib/systemd/boot/efi/linuxx64.efi.stub`` is assumed.

**SplashImage**

  The path to a bitmap image file (BMP) to use as a splash image before ZFSBootMenu loads. Only works if using systemd-boot's EFI stub loader. The ZFSBootMenu logo is available in BMP format at ``/usr/share/examples/zfsbootmenu/splash.bmp``.

EXAMPLE
=======

The following example will write separate, unversioned ZFSBootMenu kernel and initramfs images to */boot/efi/EFI/zbm*, keeping a backup for each file that would be overwritten when creating the new images. In addition, a versioned UEFI bundle will be stored in the same directory, where two prior revisions of the current version and the highest revision of each of the two most recent prior versions will be retained.

.. code-block:: yaml

  Global:
    ManageImages: true
    BootMountPoint: /boot/efi
    DracutConfDir: /etc/zfsbootmenu/dracut.conf.d
  Components:
    ImageDir: /boot/efi/EFI/zbm
    Versions: false
    Enabled: true
  EFI:
    ImageDir: /boot/efi/EFI/zbm
    Versions: 2
    Enabled: true
  Kernel:
    CommandLine: ro quiet loglevel=0

SEE ALSO
========

:doc:`generate-zbm(8) </man/generate-zbm.8>` :doc:`zfsbootmenu(7) </man/zfsbootmenu.7>`

Single-disk syslinux MBR
========================

.. |boot_disk| replace:: /dev/sda
.. |boot_part_no| replace:: 1

.. |pool_disk| replace:: /dev/sda
.. |pool_part_no| replace:: 2

.. |distribution| replace:: void

.. |zbmkcl| replace:: quiet

.. contents:: Contents
  :depth: 2
  :local:
  :backlinks: none

This guide can be used to install Void onto a single ZFS disk with or without ZFS encryption. It assumes the following:

* Your system uses BIOS to boot
* Your system is x86_64
* You will use ``glibc`` as your system libc.
* ``/dev/sda`` is the disk to be used for both ZFS and syslinux
* You're mildly comfortable with ZFS and discovering system facts on your own (``lsblk``, ``dmesg``, ``gdisk``, ...)

.. include:: ../_include/intro.rst

Download the latest `hrmpf <https://github.com/leahneukirchen/hrmpf/releases>`_, write it to USB drive and boot your
system in BIOS mode.

.. include:: _include/early-prep.rst

.. include:: ../_include/define-env.rst

Disk prep work
--------------

The disk that will hold the syslinux partition and ZFS pool should be labeled in MBR format and provide two partitions.
First, initialize a blank MBR label on the disk that will hold the syslinux boot partition:

.. code-block:: bash

  echo "label: dos" | sfdisk "$BOOT_DISK"

If the ZFS pool resides on a separate disk, also initialize a blank MBR label on the disk that will hold the pool:

.. code-block:: bash

  echo "label: dos" | sfdisk "$POOL_DISK"

Finally, create partitions for syslinux and the ZFS pool:

.. code-block:: bash

  echo "${BOOT_DEVICE}: start=1MiB, size=512MiB, type=83, bootable" | sfdisk -a "$BOOT_DISK"
  echo "${POOL_DEVICE}: start=513MiB, size=+, type=83" | sfdisk -a "$POOL_DISK"

.. note::

  The ``start`` value specified for the ``${POOL_DEVICE}`` partition was selected to ensure that the ZFS partition does
  not overlap the boot partition when both reside on the same disk. You may wish to adjust the sizes or offsets to
  better suit your needs.

.. include:: ../_include/pool-creation.rst

.. include:: ../_include/create-filesystems.rst

.. include:: _include/distro-install.rst

.. include:: _include/zfs-config.rst

Install and configure ZFSBootMenu
---------------------------------

Create a ext4 boot filesystem
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  mkfs.ext4 -O '^64bit' "$BOOT_DEVICE"

.. note::

  Under some circumstances, syslinux may fail to recognize files on an ext4 filesystem. The issue may be related to the
  ``64bit`` feature of the filesystem, which is explicitly disabled in the command above. If syslinux still fails to
  recognize files on the ext4 partition, try using ext3 or ext2 as a fallback.

Create an fstab entry and mount
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  cat << EOF >> /etc/fstab
  $( blkid | grep "$BOOT_DEVICE" | cut -d ' ' -f 2 ) /boot/syslinux ext4 defaults 0 0
  EOF

  mkdir /boot/syslinux
  mount /boot/syslinux

Install the syslinux package, copy modules
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  xbps-install -S syslinux
  cp /usr/lib/syslinux/*.c32 /boot/syslinux

Install extlinux
~~~~~~~~~~~~~~~~

.. parsed-literal::

  bash-5.0# **extlinux --install /boot/syslinux**
  /boot/syslinux is device |boot_disk|\ |boot_part_no|


Install the syslinux MBR data
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. parsed-literal::

  bash-5.0# **dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/mbr.bin of="$BOOT_DISK"**
  1+0 records in
  1+0 records out
  440 bytes copied, 0.000306845 s, 1.4 MB/s

.. include:: ../_include/zbm-setup.rst

.. include:: _include/zbm-install-package.rst

Enable zfsbootmenu image creation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Edit ``/etc/zfsbootmenu/config.yaml`` and make sure that the following parameters are set:

.. code-block:: yaml

  Global:
    ManageImages: true
    BootMountPoint: /boot/syslinux
  Components:
    Enabled: true
    Versions: false
    ImageDir: /boot/syslinux/zfsbootmenu

See :doc:`generate-zbm(5) </man/generate-zbm.5>` for more details.

Configure syslinux
~~~~~~~~~~~~~~~~~~

The ``generate-zbm`` image-creation utility includes now-deprecated support for managing a syslinux configuration.
Because this capability is slated for removal and was not reliable in the first place, it is better to create a static
syslinux configuration. The ZFSBootMenu configuration described above disables explicit image versioning, which means
that each invocation of ``generate-zbm`` will produce two output files at a predictable location:

* ``/boot/syslinux/zfsbootmenu/vmlinuz-bootmenu``
* ``/boot/syslinux/zfsbootmenu/initramfs-bootmenu.img``

In addition, any existing copies of the ZFSBootMenu kernel and initramfs will be saved to a backup location:

* ``/boot/syslinux/zfsbootmenu/vmlinuz-bootmenu-backup``
* ``/boot/syslinux/zfsbootmenu/initramfs-bootmenu-backup.img``

The following syslinux configuration will provide a simple menu that provides a choice between the current and backup
images::

  cat > /boot/syslinux/syslinux.cfg <<EOF
  UI menu.c32
  PROMPT 0

  MENU TITLE ZFSBootMenu
  TIMEOUT 50

  DEFAULT zfsbootmenu

  LABEL zfsbootmenu
    MENU LABEL ZFSBootMenu
    KERNEL /zfsbootmenu/vmlinuz-bootmenu
    INITRD /zfsbootmenu/initramfs-bootmenu.img
    APPEND zfsbootmenu quiet loglevel=4

  LABEL zfsbootmenu-backup
    MENU LABEL ZFSBootMenu (Backup)
    KERNEL /zfsbootmenu/vmlinuz-bootmenu-backup
    INITRD /zfsbootmenu/initramfs-bootmenu-backup.img
    APPEND zfsbootmenu quiet loglevel=4
  EOF

Consult the `syslinux documentation <https://wiki.syslinux.org/wiki/index.php?title=Config>`_ for more details on the
contents of the ``syslinux.cfg`` configuration file. To alter the command-line arguments passed to the ZFSBootMenu
image, adjust the contents of the ``APPEND`` lines in the configuration.

.. include:: _include/gen-initramfs.rst

.. include:: ../_include/cleanup.rst

..
  vim: softtabstop=2 shiftwidth=2 textwidth=120

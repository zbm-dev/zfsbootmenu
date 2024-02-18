SYSLINUX MBR
============

.. |distribution| replace:: void

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

.. include:: _include/live-environment.rst

.. include:: ../_include/define-env.rst

Disk preparation
----------------

The disk(s) that will hold the syslinux partition and ZFS pool should be labeled in MBR format and configured to provide
partitions for boot files as well as the ZFSBootMenu.

.. tabs::

   .. group-tab:: Single Disk

      .. code-block:: bash

         cat <<EOF | sfdisk "${POOL_DISK}"
         label: dos
         start=1MiB, size=512MiB, type=83, bootable
         start=513MiB, size=+, type=83
         EOF

   .. group-tab:: Separate Boot Device

      .. code-block:: bash

         cat <<EOF | sfdisk "${POOL_DISK}"
         label: dos
         start=1MiB, size=+, type=83, bootable
         EOF

         cat <<EOF | sfdisk "${BOOT_DISK}"
         label: dos
         start=1MiB, size=512MiB, type=83
         EOF

.. include:: ../_include/pool-creation.rst

.. include:: ../_include/create-filesystems.rst

.. include:: ../_include/update-devices.rst

.. include:: _include/distro-install.rst

.. include:: _include/zfs-config.rst

Install and configure syslinux
------------------------------

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

.. code-block::

  extlinux --install /boot/syslinux


Install the syslinux MBR data
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/mbr.bin of="$BOOT_DISK"

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

The ZFSBootMenu configuration described above disables explicit image versioning, which means
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
    APPEND zfsbootmenu quiet

  LABEL zfsbootmenu-backup
    MENU LABEL ZFSBootMenu (Backup)
    KERNEL /zfsbootmenu/vmlinuz-bootmenu-backup
    INITRD /zfsbootmenu/initramfs-bootmenu-backup.img
    APPEND zfsbootmenu quiet
  EOF

Consult the `syslinux documentation <https://wiki.syslinux.org/wiki/index.php?title=Config>`_ for more details on the
contents of the ``syslinux.cfg`` configuration file. To alter the command-line arguments passed to the ZFSBootMenu
image, adjust the contents of the ``APPEND`` lines in the configuration.

Alternatively, the :zbm:`contrib/syslinux-update.sh` ``generate-zbm`` hook can be used to automatically recreate
``syslinux.cfg``.

.. include:: _include/gen-initramfs.rst

.. include:: ../_include/cleanup.rst

..
  vim: softtabstop=2 shiftwidth=2 textwidth=120

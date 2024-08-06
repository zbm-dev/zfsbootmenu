ZFS Configuration
-----------------

Install ZFS
~~~~~~~~~~~

.. code-block::

  apk add zfs zfs-lts zfs-scripts
  rc-update add zfs-import sysinit
  rc-update add zfs-mount sysinit

Configure mkinitfs to load ZFS support
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Unencrypted

    .. code-block::

      echo "/etc/hostid" >> /etc/mkinitfs/features.d/zfshost.files
      echo 'features="ata base keymap kms mmc scsi usb virtio nvme zfs zfshost"' > /etc/mkinitfs/mkinitfs.conf

  .. group-tab:: Encrypted

    .. code-block::

      echo "/etc/hostid" >> /etc/mkinitfs/features.d/zfshost.files
      echo "/etc/zfs/zroot.key" >> /etc/mkinitfs/features.d/zfshost.files
      echo 'features="ata base keymap kms mmc scsi usb virtio nvme zfs zfshost"' > /etc/mkinitfs/mkinitfs.conf

Regenerate initramfs
~~~~~~~~~~~~~~~~~~~~

.. code-block::

   mkinitfs -c /etc/mkinitfs/mkinitfs.conf "$(ls /lib/modules)"

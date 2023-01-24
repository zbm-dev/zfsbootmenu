ZFS Configuration
-----------------

Install required packages
~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  apt install dosfstools zfs-initramfs zfsutils-linux

Enable systemd ZFS services
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  systemctl enable zfs.target
  systemctl enable zfs-import-cache
  systemctl enable zfs-mount
  systemctl enable zfs-import.target

Configure ``initramfs-tools``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Unencrypted

    No required steps

  .. group-tab:: Encrypted

    .. code-block::

      echo "UMASK=0077" > /etc/initramfs-tools/conf.d/umask.conf

    .. note::

      Because the encryption key is stored in ``/etc/zfs`` directory, it will automatically be copied into the system
      initramfs.

Rebuild the initramfs
~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  update-initramfs -c -k all

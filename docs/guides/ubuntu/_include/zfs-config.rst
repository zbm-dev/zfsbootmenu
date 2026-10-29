ZFS Configuration
-----------------

Install required packages
~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  apt install dosfstools dracut zfs-dracut zfsutils-linux

Enable systemd ZFS services
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  systemctl enable zfs.target
  systemctl enable zfs-import-cache
  systemctl enable zfs-mount
  systemctl enable zfs-import.target

Configure ``dracut``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Unencrypted

    No required steps

  .. group-tab:: Encrypted

    .. code-block::

      echo 'install_items+=" /etc/zfs/zroot.key "' > /etc/dracut.conf.d/zfskey.conf

    .. note::

      Because the encryption key is stored in ``/etc/zfs`` directory, it will automatically be copied into the system
      initramfs.

Rebuild the initramfs
~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  dracut --force --regenerate-all

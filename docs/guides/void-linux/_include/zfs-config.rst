ZFS Configuration
-----------------

Configure Dracut to load ZFS support
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Encrypted

    .. code-block::

      cat << EOF > /etc/dracut.conf.d/zol.conf
      nofsck="yes"
      add_dracutmodules+=" zfs "
      omit_dracutmodules+=" btrfs "
      install_items+=" /etc/zfs/zroot.key "
      EOF

  .. group-tab:: Unencrypted

    .. code-block::

      cat << EOF > /etc/dracut.conf.d/zol.conf
      nofsck="yes"
      add_dracutmodules+=" zfs "
      omit_dracutmodules+=" btrfs "
      EOF

Install ZFS
~~~~~~~~~~~

.. code-block::

  xbps-install -S zfs

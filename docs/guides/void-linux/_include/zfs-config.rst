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

Set up pool caching
~~~~~~~~~~~~~~~~~~~

To more quickly discover and import pools on boot, we need to set a pool cachefile::

  zpool set cachefile=/etc/zfs/zpool.cache zroot

Configure our default boot environment
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  zpool set bootfs=zroot/ROOT/void zroot

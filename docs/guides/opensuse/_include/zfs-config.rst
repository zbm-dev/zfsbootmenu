ZFS Configuration
-----------------

Configure Dracut to load ZFS support
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Unencrypted

    .. code-block::

      cat << EOF > /etc/dracut.conf.d/zol.conf
      nofsck="yes"
      add_dracutmodules+=" zfs "
      omit_dracutmodules+=" btrfs "
      EOF

  .. group-tab:: Encrypted

    .. code-block::

      cat << EOF > /etc/dracut.conf.d/zol.conf
      nofsck="yes"
      add_dracutmodules+=" zfs "
      omit_dracutmodules+=" btrfs "
      install_items+=" /etc/zfs/zroot.key "
      EOF

Install kernel packages
~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  zypper -n install kernel-default kernel-firmware

Install ZFS
~~~~~~~~~~~

.. code-block::

  zypper -n install zfs zfs-kmp-default

Build Kernel Modules
~~~~~~~~~~~~~~~~~~~~

.. code-block::

  dracut --regenerate-all --force

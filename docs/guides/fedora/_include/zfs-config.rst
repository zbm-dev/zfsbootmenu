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

Install required packages
~~~~~~~~~~~~~~~~~~~~~~~~~

As in the live environment, import useful variables to describe the system.

.. code-block:: bash

  source /etc/os-release

.. include:: ./_include/zfs-packages.rst

Finally, install the ``dracut`` module necessary for importing pools at boot time and re-enable the ``updates`` repository.

.. code-block::

  dnf install -y zfs-dracut

  dnf config-manager --enable updates


Regenerate initramfs
~~~~~~~~~~~~~~~~~~~~

.. code-block::

  dracut --force --regenerate-all

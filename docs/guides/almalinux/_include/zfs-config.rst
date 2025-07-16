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

.. code-block::

  source /etc/os-release

  dnf install -y https://zfsonlinux.org/epel/zfs-release-2-3$(rpm --eval "%{dist}").noarch.rpm
  dnf install -y epel-release
  dnf install -y kernel kernel-devel sudo console-setup efibootmgr langpacks-en dosfstools
  dnf install -y zfs zfs-dracut
  dnf reinstall -y kernel-core


.. note::

  Missing kernel messages can be ignored during this step.

Regenerate initramfs
~~~~~~~~~~~~~~~~~~~~

.. code-block::

  dracut --force --regenerate-all

.. note::

  Ignore any messages about "findmnt".

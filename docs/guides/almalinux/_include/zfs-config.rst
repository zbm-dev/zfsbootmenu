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
  dnf install -y zfs zfs-dracut sudo console-setup efibootmgr langpacks-en dosfstools
  dnf install -y kernel kernel-devel


.. note::

  Ignore missing kernel messages, we haven't installed the kernel yet, when we do install the kernel after ZFS, dkms will install the module as it should.

Regenerate initramfs
~~~~~~~~~~~~~~~~~~~~

.. code-block::

  rpm -q kernel
  dracut --force --kver 5.14.0-570.25.1.el9_6.x86_64

.. note::

  Find the newly installed kernel version using rpm, and then tell dracut to regenerate it's initramfs,
  ignore any messages about "findmnt".

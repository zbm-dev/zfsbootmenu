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

  rpm -e --nodeps zfs-fuse

  dnf config-manager --disable updates

  dnf install -y https://dl.fedoraproject.org/pub/fedora/linux/releases/${VERSION_ID}/Everything/x86_64/os/Packages/k/kernel-devel-$(uname -r).rpm

  dnf --releasever=${VERSION_ID} install -y \
    https://zfsonlinux.org/fedora/zfs-release-2-5$(rpm --eval "%{dist}").noarch.rpm

  dnf install -y zfs zfs-dracut

  dnf config-manager --enable updates

.. note::

  The ``updates`` repository is temporarily disabled to ensure that the correct kernel-headers package can be located and installed.

Regenerate initramfs
~~~~~~~~~~~~~~~~~~~~

.. code-block::

  dracut --force --regenerate-all

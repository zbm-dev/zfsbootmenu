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

Install required packages
~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  source /etc/os-release

  rpm -e --nodeps zfs-fuse

  dnf install -y https://dl.fedoraproject.org/pub/fedora/linux/releases/${VERSION_ID}/Everything/x86_64/os/Packages/k/kernel-devel-$(uname -r).rpm

  dnf --releasever=${VERSION_ID} -y install \
    https://zfsonlinux.org/fedora/zfs-release-2-2$(rpm --eval "%{dist}").noarch.rpm

  dnf install -y install zfs zfs-dracut

Build Kernel Modules
~~~~~~~~~~~~~~~~~~~~

.. code-block::

  ls /lib/modules | xargs -n1 dkms autoinstall -k
  dracut --regenerate-all --force

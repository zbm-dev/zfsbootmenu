Configure Live Environment
--------------------------

Switch to a root account
~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  sudo -i

.. include:: ../_include/os-release.rst

Install updated ZFS packages
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

   rpm -e --nodeps zfs-fuse
   dnf config-manager --disable updates
   dnf install -y https://zfsonlinux.org/fedora/zfs-release-2-5$(rpm --eval "%{dist}").noarch.rpm
   dnf install -y https://dl.fedoraproject.org/pub/fedora/linux/releases/${VERSION_ID}/Everything/x86_64/os/Packages/k/kernel-devel-$(uname -r).rpm
   dnf install -y zfs gdisk
   modprobe zfs

.. include:: ../_include/zgenhostid.rst

..
 vim: softtabstop=2 shiftwidth=2 textwidth=120

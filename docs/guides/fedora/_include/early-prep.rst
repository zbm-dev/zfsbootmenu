Early Setup
-----------

Switch to a root account

.. code-block::

  sudo -i

Set release related variables

.. code-block::

  source /etc/os-release

Install updated ZFS packages

.. code-block::

   rpm -e --nodeps zfs-fuse
   dnf install -y https://zfsonlinux.org/fedora/zfs-release-2-2$(rpm --eval "%{dist}").noarch.rpm
   dnf install -y https://dl.fedoraproject.org/pub/fedora/linux/releases/${VERSION_ID}/Everything/x86_64/os/Packages/k/kernel-devel-$(uname -r).rpm
   dnf install -y zfs
   modprobe zfs

Generate a hostid

.. code-block::

  zgenhostid

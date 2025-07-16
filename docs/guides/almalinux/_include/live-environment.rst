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

   dnf install -y https://zfsonlinux.org/epel/zfs-release-2-3$(rpm --eval "%{dist}").noarch.rpm
   dnf install -y epel-release 
   dnf install -y "kernel-devel-uname-r == $(uname -r)"
   dnf install -y zfs gdisk
   modprobe zfs

.. include:: ../_include/zgenhostid.rst

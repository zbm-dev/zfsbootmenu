Install Alma 
--------------

Mount kernel virtual filesystems (proc, sysfs, dev, devpts)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  mkdir /mnt/proc /mnt/sys /mnt/dev /mnt/dev/pts
  mount -t proc proc /mnt/proc
  mount -t sysfs sys /mnt/sys
  mount -B /dev /mnt/dev
  mount -t devpts pts /mnt/dev/pts


Install Minimal Base
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. parsed-literal::

  dnf --installroot=/mnt --releasever=\ |releasever| -y groupinstall "Minimal Install"

Copy files into the new install
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Unencrypted

    .. code-block:: bash

      cp -L /etc/resolv.conf /mnt/etc
      cp /etc/hostid /mnt/etc

  .. group-tab:: Encrypted

    .. code-block:: bash

      cp -L /etc/resolv.conf /mnt/etc
      cp /etc/hostid /mnt/etc
      mkdir -p /mnt/etc/zfs
      cp /etc/zfs/zroot.key /mnt/etc/zfs

Chroot into the new OS
~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  chroot /mnt /bin/bash

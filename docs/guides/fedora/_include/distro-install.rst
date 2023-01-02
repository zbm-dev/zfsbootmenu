Install Fedora 
--------------

.. code-block:: bash
  
  mkdir /run/install
  mount /dev/mapper/live-base /run/install
   
  rsync -pogAXtlHrDx \
   --stats \
   --exclude=/boot/efi/* \
   --exclude=/etc/machine-id \
   --info=progress2 \
   /run/install/ /mnt

Copy files into the new install
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Encrypted

    .. code-block:: bash

      mv /mnt/etc/resolv.conf /mnt/etc/resolv.conf.orig
      cp /etc/hostid /mnt/etc
      cp -L /etc/resolv.conf /mnt/etc
      mkdir -p /mnt/etc/zfs
      cp /etc/zfs/zpool.cache /mnt/etc/zfs
      cp /etc/zfs/zroot.key /mnt/etc/zfs

  .. group-tab:: Unencrypted

    .. code-block:: bash

      mv /mnt/etc/resolv.conf /mnt/etc/resolv.conf.orig
      cp -L /etc/resolv.conf /mnt/etc
      cp /etc/hostid /mnt/etc
      mkdir -p /mnt/etc/zfs
      cp /etc/zfs/zpool.cache /mnt/etc/zfs

Chroot into the new OS
~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  mount -t proc proc /mnt/proc
  mount -t sysfs sys /mnt/sys
  mount -B /dev /mnt/dev
  mount -t devpts pts /mnt/dev/pts
  chroot /mnt /bin/bash

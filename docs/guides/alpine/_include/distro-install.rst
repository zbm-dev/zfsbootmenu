Install Alpine 
--------------

.. code-block::

   apk --arch x86_64 -X http://dl-cdn.alpinelinux.org/alpine/latest-stable/main \
    -U --allow-untrusted --root /mnt --initdb add alpine-base

Copy our files into the new install
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Unencrypted

    .. code-block::

      cp /etc/hostid /mnt/etc
      cp /etc/resolv.conf /mnt/etc
      cp /etc/apk/repositories /mnt/etc/apk
      cp /etc/network/interfaces /mnt/etc/network

  .. group-tab:: Encrypted

    .. code-block::

      cp /etc/hostid /mnt/etc
      cp /etc/resolv.conf /mnt/etc
      cp /etc/apk/repositories /mnt/etc/apk
      cp /etc/network/interfaces /mnt/etc/network
      mkdir /mnt/etc/zfs
      cp /etc/zfs/zroot.key /mnt/etc/zfs

Chroot into the new OS
~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

   mount --rbind /dev /mnt/dev
   mount --rbind /sys /mnt/sys
   mount --rbind /proc /mnt/proc
   chroot /mnt

Set a root password
~~~~~~~~~~~~~~~~~~~

.. code-block::

  passwd

Enable startup targets
~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  rc-update add hwdrivers sysinit
  rc-update add networking
  rc-update add hostname

Install Chimera 
---------------

.. code-block::

  chimera-bootstrap /mnt

Copy our files into the new install
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Unencrypted

    .. code-block::

      cp /etc/hostid /mnt/etc

  .. group-tab:: Encrypted

    .. code-block::

      cp /etc/hostid /mnt/etc
      mkdir /mnt/etc/zfs
      cp /etc/zfs/zroot.key /mnt/etc/zfs

Chroot into the new OS
~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  chimera-chroot /mnt

Set a root password
~~~~~~~~~~~~~~~~~~~

.. code-block::

  passwd

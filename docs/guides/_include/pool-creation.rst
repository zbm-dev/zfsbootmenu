ZFS pool creation
-----------------

Create the zpool
~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Unencrypted

    .. code-block::

      zpool create -f -o ashift=12 \
       -O compression=lz4 \
       -O acltype=posixacl \
       -O xattr=sa \
       -O relatime=on \
       -o autotrim=on \
       -o compatibility=openzfs-2.1-linux \
       -m none zroot "$POOL_DEVICE"

  .. group-tab:: Encrypted

    .. code-block:: bash

      echo 'SomeKeyphrase' > /etc/zfs/zroot.key
      chmod 000 /etc/zfs/zroot.key

    .. code-block:: bash

      zpool create -f -o ashift=12 \
       -O compression=lz4 \
       -O acltype=posixacl \
       -O xattr=sa \
       -O relatime=on \
       -O encryption=aes-256-gcm \
       -O keylocation=file:///etc/zfs/zroot.key \
       -O keyformat=passphrase \
       -o autotrim=on \
       -o compatibility=openzfs-2.1-linux \
       -m none zroot "$POOL_DEVICE"

    .. note::

      It's out of the scope of this guide to cover all of the pool creation options used - feel free to tailor them to
      suit your system. However, the following options need to be addressed:

      * ``encryption=aes-256-gcm`` - You can adjust the algorithm as you see fit, but this will likely be the most
        performant on modern x86_64 hardware.
      * ``keylocation=file:///etc/zfs/zroot.key`` - This sets our pool encryption passphrase to the file
        ``/etc/zfs/zroot.key``, which we created in a previous step. This file will live inside your initramfs stored
        *on* the ZFS boot environment.
      * ``keyformat=passphrase`` - By setting the format to ``passphrase``, we can now force a prompt for this in
        ``zfsbootmenu``. It's critical that your passphrase be something you can type on your keyboard, since you will
        need to type it in to unlock the pool on boot.

.. note::

  The option ``-o compatibility=openzfs-2.1-linux`` is a conservative choice. It can be omitted or otherwise adjusted to match your specific system needs.

  Binary releases of ZFSBootMenu are generally built with the latest stable release of ZFS. Future releases of ZFSBootMenu may therefore support newer feature sets. Check project release notes prior to updating or removing ``compatibility`` options and upgrading your system pool.

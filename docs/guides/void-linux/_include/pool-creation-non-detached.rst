ZFS pool creation
-----------------

Create the zpool
~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Encrypted

    .. code-block::

      zpool create -f -o ashift=12 \
       -O compression=lz4 \
       -O acltype=posixacl \
       -O xattr=sa \
       -O relatime=on \
       -O encryption=aes-256-gcm \
       -O keylocation=file:///etc/zfs/zroot.key \
       -O keyformat=passphrase \
       -o autotrim=on \
       -m none zroot /dev/sda2

    .. include:: _include/enc-pool-creation-notes.rst

  .. group-tab:: Unencrypted

    .. code-block::

      zpool create -f -o ashift=12 \
       -O compression=lz4 \
       -O acltype=posixacl \
       -O xattr=sa \
       -O relatime=on \
       -o autotrim=on \
       -m none zroot /dev/sda2

Install and configure ZFSBootMenu
---------------------------------

Set ZFSBootMenu properties on datasets
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Unencrypted

      Assign command-line arguments to be used when booting the final kernel. Because ZFS properties are inherited,
      assign the common properties to the ``ROOT`` dataset so all children will inherit common arguments by default.

      .. include:: _include/commandline.rst

  .. group-tab:: Encrypted

      Assign command-line arguments to be used when booting the final kernel. Because ZFS properties are inherited,
      assign the common properties to the ``ROOT`` dataset so all children will inherit common arguments by default.

      .. include:: _include/commandline.rst

      Setup key caching in ZFSBootMenu.

      .. code-block::

        zfs set org.zfsbootmenu:keysource="zroot/ROOT/${ID}" zroot

Set ZFSBootMenu properties on datasets
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Assign command-line arguments to be used when booting the final kernel. Because ZFS properties are inherited, assign the
common properties to the ``ROOT`` dataset so all children will inherit common arguments by default.

.. code-block::

  zfs set org.zfsbootmenu:commandline="quiet" zroot/ROOT

Install the ZFSBootMenu package
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  xbps-install -S zfsbootmenu

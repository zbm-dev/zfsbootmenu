ZFS prep work
-------------

Build and load ZFS modules
~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  xbps-reconfigure -a
  modprobe zfs

Generate ``/etc/hostid``
~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  zgenhostid

Store your pool passphrase in a key file
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. note::

  This is only for systems with encryption.

.. code-block::

  echo 'SomeKeyphrase' > /etc/zfs/zroot.key
  chmod 000 /etc/zfs/zroot.key

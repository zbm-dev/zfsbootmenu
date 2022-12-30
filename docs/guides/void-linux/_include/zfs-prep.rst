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

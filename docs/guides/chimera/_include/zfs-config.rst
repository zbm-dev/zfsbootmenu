ZFS Configuration
-----------------

Configure initramfs-tools
~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Unencrypted

    .. code-block::

      No required steps

  .. group-tab:: Encrypted

    .. code-block::

      echo "UMASK=0077" > /etc/initramfs-tools/conf.d/umask.conf

Install ZFS and kernel
~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  apk add --no-interactive linux-lts-zfs-bin

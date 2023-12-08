Disk preparation
----------------

Wipe partitions
~~~~~~~~~~~~~~~

.. code-block:: bash

  zpool labelclear -f "$POOL_DISK"

  wipefs -a "$POOL_DISK"
  wipefs -a "$BOOT_DISK"

  sgdisk --zap-all "$POOL_DISK"
  sgdisk --zap-all "$BOOT_DISK"

Create EFI boot partition
~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  sgdisk -n "${BOOT_PART}:1m:+512m" -t "${BOOT_PART}:ef00" "$BOOT_DISK"

Create zpool partition 
~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  sgdisk -n "${POOL_PART}:0:-10m" -t "${POOL_PART}:bf00" "$POOL_DISK"

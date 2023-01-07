Define disk variables 
---------------------

For convenience and to reduce the likelihood of errors, set environment variables that refer to the devices that
will be configured during the setup.

For many users, it is most convenient to place boot files (*i.e.*, ZFSBootMenu and any loader responsible for
launching it) on the the same disk that will hold the ZFS pool. However, some users may wish to dedicate an entire
disk to the ZFS pool or create a multi-disk pool. A USB flash drive provides a convenient location for the
boot partition. Fortunately, this alternative configuration is easily realized by simply defining a few environment
variables differently.

Verify your target disk devices with ``lsblk``. ``/dev/sda`` and ``/dev/sdb`` used below are examples.

First, define variables that refer to the disk and partition number that will hold **boot files**:

.. tabs::

   .. group-tab:: Single Disk

      .. code-block::

        export BOOT_DISK="/dev/sda"
        export BOOT_PART="1"
        export BOOT_DEVICE="${BOOT_DISK}${BOOT_PART}"

   .. group-tab:: Separate Boot Device

      .. code-block::

        export BOOT_DISK="/dev/sdb"
        export BOOT_PART="1"
        export BOOT_DEVICE="${BOOT_DISK}${BOOT_PART}"

Next, define variables that refer to the disk and partition number that will hold the **ZFS pool**:

.. tabs::

   .. group-tab:: Single Disk

      .. code-block::

        export POOL_DISK="/dev/sda"
        export POOL_PART="2"
        export POOL_DEVICE="${POOL_DISK}${POOL_PART}"

   .. group-tab:: Separate Boot Device

      .. code-block::

        export POOL_DISK="/dev/sda"
        export POOL_PART="1"
        export POOL_DEVICE="${POOL_DISK}${POOL_PART}"

..
  vim: softtabstop=2 shiftwidth=2 textwidth=120

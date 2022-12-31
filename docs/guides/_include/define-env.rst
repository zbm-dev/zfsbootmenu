Define the environment
----------------------

For convenience and to reduce the likelihood of errors, set environment variables that refer to the devices that
will be configured during the setup. Verify your target disk devices with ``lsblk``.

First, define variables that refer to the disk and partition number that will hold boot files:

.. parsed-literal::

   export BOOT_DISK="\ |boot_disk|"
   export BOOT_PART="\ |boot_part_no|"
   export BOOT_DEVICE="${BOOT_DISK}${BOOT_PART}"

Next, define variables that refer to the disk and partition number that will hold the ZFS pool:

.. parsed-literal::

   export POOL_DISK="\ |pool_disk|"
   export POOL_PART="\ |pool_part_no|"
   export POOL_DEVICE="${POOL_DISK}${POOL_PART}"

These definitions may be adjusted as needed to accommodate your system.

..
  vim: softtabstop=2 shiftwidth=2 textwidth=120

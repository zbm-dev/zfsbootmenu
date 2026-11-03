Hardware Quirks
===============

.. contents:: Contents
  :depth: 1
  :local:
  :backlinks: none


Some computers have issues running ZFSBootMenu, or issues with hardware after
booting into a boot environment with ``kexec``.

Contributions to this page with additional hardware quirks and solutions are encouraged.

..
   Template:

   Hardware
   --------

   Symptoms
   ^^^^^^^^
   Describe how to detect the problem

   Solution
   ^^^^^^^^
   Describe how to resolve the issue

HP Omen 16 2022
---------------

Symptoms
^^^^^^^^

Non-functional touchpad, this log entry::

   kernel: i2c_designware AMDI0010:03: Unknown Synopsys component type: 0xffffffff

Solution
^^^^^^^^

If the driver is compiled into your kernel: append ``initcall_blacklist=dw_i2c_init_driver,dw_i2c_driver_init`` to the ZFSBootMenu kernel command line.

If the driver is compiled as module: blacklist the module in ZFSBootMenu by appending ``i2c_designware_pci.blacklist=yes`` to the ZFSBootMenu kernel command line.

Dell Servers
------------

Symptoms
^^^^^^^^

The ZFSBootMenu EFI image does not boot, either directly or via rEFInd, with the message::

   Execution of embedded linux image failed: Out of Resources

Solution
^^^^^^^^

Use rEFInd to boot the Components format (kernel and initramfs) of ZFSBootMenu.

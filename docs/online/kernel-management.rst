Kernel Management
=================

Keyboard Shortcuts
------------------

*[ENTER]* **boot**

  Immediately boot the chosen kernel in the selected boot environment, with the kernel command line shown at the top of the screen.

*[MOD+D]* **set default**

  Set the selected kernel as the default for the boot environment.

  The ZFS property *org.zfsbootmenu:kernel* is used to store the default kernel for the boot environment.

  The operation will fail gracefully if the pool can not be set *read/write*.

*[MOD+U]* **unset default**

  Inherit the ZFS property *org.zfsbootmenu:kernel* from a parent if present, otherwise unset the property.

  The operation will fail gracefully if the pool can not be set *read/write*.

*[MOD+L]* **view logs**

  View logs, as indicated by *[!]*. The indicator will be yellow for warning conditions and red for errors.

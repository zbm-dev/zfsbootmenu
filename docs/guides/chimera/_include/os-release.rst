Source ``/etc/os-release``
~~~~~~~~~~~~~~~~~~~~~~~~~~

The file `/etc/os-release` defines variables that describe the running distribution. In particular, the `$ID` variable
defined within can be used as a short name for the filesystem that will hold this installation.

.. code-block::

  . /etc/os-release
  export ID

..
  vim: softtabstop=2 shiftwidth=2 textwidth=120

Configure Live Environment
--------------------------

Open a root shell
~~~~~~~~~~~~~~~~~

Open a terminal on the live installer session, then:

.. code-block::

  sudo -i

.. include:: ../_include/efi-boot-check.rst

.. include:: ../_include/os-release.rst

Install helpers
~~~~~~~~~~~~~~~

.. code-block::

  apt update
  apt install debootstrap gdisk zfsutils-linux

.. include:: ../_include/zgenhostid.rst
..
 vim: softtabstop=2 shiftwidth=2 textwidth=120

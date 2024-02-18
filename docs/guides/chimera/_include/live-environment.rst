Configure Live Environment
--------------------------

Switch to a root account
~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  doas -s

.. note::

   The default password for the ``root`` account is ``chimera``.

.. include:: _include/os-release.rst

Update package repositories
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  apk add --no-interactive chimera-repo-contrib
  apk update

Setup additional tools 
~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  apk add --no-interactive gptfdisk

.. include:: ../_include/zgenhostid.rst

..
  vim: softtabstop=2 shiftwidth=2 textwidth=120

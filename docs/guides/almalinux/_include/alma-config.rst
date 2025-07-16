Configure Alma
--------------------------

Set hostname
~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  hostname AlmaRocks
  hostname > /etc/hostname

Fix SELinux filesystem labels
~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  fixfiles -F -f relabel

Set a root password
~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  passwd
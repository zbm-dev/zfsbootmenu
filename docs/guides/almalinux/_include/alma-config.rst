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

Create initial admin user
~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  adduser -G wheel fred
  passwd fred
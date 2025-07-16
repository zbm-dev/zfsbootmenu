Configure EFI boot entries
~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

   mount -t efivarfs efivarfs /sys/firmware/efi/efivars

.. tabs::

  .. group-tab:: Direct

    .. include:: ../_include/configure-efibootmgr.rst
  
  .. group-tab:: rEFInd

    .. code-block::

      dnf install -y refind 

    .. include:: ../_include/configure-refind.rst

.. include:: ../_include/efi-seealso.rst

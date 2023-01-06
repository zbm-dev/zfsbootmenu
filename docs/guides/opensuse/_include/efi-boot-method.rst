Configure EFI boot entries
~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

   mount -t efivarfs efivarfs /sys/firmware/efi/efivars

.. tabs::

  .. code-block::

    zypper -n install efibootmgr

  .. group-tab:: Direct

    .. include:: ../_include/configure-efibootmgr.rst
  
  .. group-tab:: rEFInd

    .. code-block::

      zypper -n install refind 

    .. include:: ../_include/configure-refind.rst

.. include:: ../_include/efi-seealso.rst

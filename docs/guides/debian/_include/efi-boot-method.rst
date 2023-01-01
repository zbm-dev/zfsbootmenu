Configure EFI boot entries
~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

   mount -t efivarfs efivarfs /sys/firmware/efi/efivars

.. tabs::

  .. group-tab:: Direct

    .. code-block:: bash

      apt install efibootmgr

    .. include:: ../_include/configure-efibootmgr.rst
  
  .. group-tab:: rEFInd

    .. code-block::

      apt install refind

    .. include:: ../_include/configure-refind.rst

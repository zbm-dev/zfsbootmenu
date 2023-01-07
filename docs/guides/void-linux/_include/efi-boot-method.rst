Configure EFI boot entries
~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Direct

    .. code-block:: bash

        xbps-install efibootmgr

    .. include:: ../_include/configure-efibootmgr.rst
  
  .. group-tab:: rEFInd

    .. code-block:: bash

      xbps-install -S refind

    .. include:: ../_include/configure-refind.rst

.. include:: ../_include/efi-seealso.rst

Configure EFI boot entries
~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Direct

    .. parsed-literal::

        xbps-install efibootmgr

    .. include:: ../_include/configure-efibootmgr.rst
  
  .. group-tab:: rEFInd

    .. parsed-literal::

      xbps-install -S refind

    .. include:: ../_include/configure-refind.rst

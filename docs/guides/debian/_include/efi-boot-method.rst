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

      ln -s /proc/self/mounts /etc/mtab
      apt install refind

    .. include:: ../_include/configure-refind.rst

.. include:: ../_include/efi-seealso.rst

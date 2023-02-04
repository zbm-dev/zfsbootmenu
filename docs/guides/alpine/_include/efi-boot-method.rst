Configure EFI boot entries
~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Direct

    .. code-block:: bash

        apk add efibootmgr

    .. include:: ../_include/configure-efibootmgr.rst
  
  .. group-tab:: rEFInd

    .. code-block:: bash

      cat <<EOF >> /etc/apk/repositories
      http://dl-cdn.alpinelinux.org/alpine/edge/testing
      EOF

      apk update
      apk add refind

    .. include:: ../_include/configure-refind.rst

.. include:: ../_include/efi-seealso.rst

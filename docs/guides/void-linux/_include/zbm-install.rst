Install ZFSBootMenu
~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Package 

    .. code-block::

      xbps-install -S zfsbootmenu gummiboot-efistub

    .. include:: ../_include/configure-gen-zbm.rst

    .. include:: ../_include/gen-initramfs.rst

  .. group-tab:: Prebuilt

    .. code-block:: bash

      xbps-install -S curl 

    .. include:: ../_include/zbm-install-prebuilt.rst

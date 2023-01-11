Download the latest ZFSBootMenu source and install on the host:

.. code-block::

  mkdir -p /usr/local/src/zfsbootmenu
  cd /usr/local/src/zfsbootmenu
  curl -L https://get.zfsbootmenu.org/source | tar -zxv --strip-components=1 -f -
  make core dracut

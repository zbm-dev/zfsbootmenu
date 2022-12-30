Clone the ZFSBootMenu repository and install on the host:

.. code-block::

  mkdir -p /usr/local/src
  cd /usr/local/src
  git clone 'https://github.com/zbm-dev/zfsbootmenu.git'
  cd zfsbootmenu
  make core dracut

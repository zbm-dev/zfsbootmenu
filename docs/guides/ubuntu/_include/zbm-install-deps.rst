Install all packages required to build a ZFSBootMenu image on Ubuntu:

.. code-block:: bash

  apt install \
    libsort-versions-perl \
    libboolean-perl \
    libyaml-pp-perl \
    git \
    fzf \
    make \
    mbuffer \
    kexec-tools \
    dracut-core \
    efibootmgr \
    bsdextrautils

.. note::

  Choose 'No' when asked if kexec-tools should handle reboots.

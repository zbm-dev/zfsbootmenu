Install all packages required to build a ZFSBootMenu image on Debian:

.. code-block:: bash

  apt install \
    libsort-versions-perl \
    libboolean-perl \
    libyaml-pp-perl \
    git \
    fzf \
    curl \
    mbuffer \
    kexec-tools \
    dracut-core \
    efibootmgr \
    systemd-boot-efi \
    bsdextrautils

.. note::

  Choose 'No' when asked if kexec-tools should handle reboots.

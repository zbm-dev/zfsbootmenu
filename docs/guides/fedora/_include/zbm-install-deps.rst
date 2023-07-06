Install all packages required to build a ZFSBootMenu image on Fedora:

.. code-block:: bash

  dnf install -y \
    systemd-boot-unsigned \
    perl-YAML-PP \
    perl-Sort-Versions \
    perl-boolean \
    git \
    fzf \
    mbuffer \
    kexec-tools

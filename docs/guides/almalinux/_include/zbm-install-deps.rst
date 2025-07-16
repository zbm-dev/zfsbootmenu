Install all packages required to build a ZFSBootMenu image on Alma:

.. code-block:: bash

  dnf config-manager --set-enabled crb
  dnf install -y \
    systemd-boot-unsigned \
    perl-YAML-PP \
    perl-Sort-Versions \
    perl-boolean \
    git \
    fzf \
    mbuffer \
    kexec-tools

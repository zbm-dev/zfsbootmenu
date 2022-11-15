#!/bin/bash

# Clone ZFSBootMenu and install
( cd / && git clone https://github.com/zbm-dev/zfsbootmenu.git )
( cd /zfsbootmenu && make install )

# Install perl dependencies if necessary
if [ -z "${SKIP_PERL}" ]; then
  ( cd /zfsbootmenu && cpanm --notest --installdeps . )
fi

# Adjust the configuration for convenient builds
if [ -f /etc/zfsbootmenu/config.yaml ]; then
  sed -e 's/Versions:.*/Versions: false/' \
      -e 's/ManageImages:.*/ManageImages: true/' \
      -e 's@ImageDir:.*@ImageDir: /zfsbootmenu/build@' \
      -e '/BootMountPoint:/d' -i /etc/zfsbootmenu/config.yaml

  case "${INITCPIO}" in
    [Yy][Ee][Ss]|[Yy]|[Oo][Nn]|1)
      sed -e "s/InitCPIO:.*/InitCPIO: true/" -i /etc/zfsbootmenu/config.yaml
      ;;
    [Nn][Oo]|[Nn]|[Oo][Ff][Ff]|0)
      sed -e "s/InitCPIO:.*/InitCPIO: false/" -i /etc/zfsbootmenu/config.yaml
      ;;
  esac
fi

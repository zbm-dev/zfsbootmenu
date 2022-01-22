#!/bin/bash

# Pre-populate ZFSBootMenu
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
fi

# Replace key parts with symlinks to reflect source changes
rm -f /usr/bin/generate-zbm
ln -s /zfsbootmenu/bin/generate-zbm /usr/bin/

rm -rf /usr/lib/dracut/modules.d/90zfsbootmenu
ln -s /zfsbootmenu/dracut /usr/lib/dracut/modules.d/90zfsbootmenu

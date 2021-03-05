#!/bin/bash

# Pre-populate ZFSBootMenu and all Perl dependencies
( cd / && git clone https://github.com/zbm-dev/zfsbootmenu.git )
( cd /zfsbootmenu && cpanm --notest --installdeps . && make install )

# Adjust the configuration for convenient builds
if [ -f /etc/zfsbootmenu/config.yaml ]; then
  sed -e 's/Versions:.*/Versions: false/' \
	  -e 's/ManageImages:.*/ManageImages: true/' \
	  -e 's@ImageDir:.*@ImageDir: /zfsbootmenu/build@' \
	  -e '/BootMountPoint:/d' -i /etc/zfsbootmenu/config.yaml
fi

rm -f /usr/bin/generate-zbm
ln -s /zfsbootmenu/bin/generate-zbm /usr/bin/

rm -rf /usr/lib/dracut/modules.d/90zfsbootmenu
ln -s /zfsbootmenu/90zfsbootmenu /usr/lib/dracut/modules.d/

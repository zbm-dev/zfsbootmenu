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

  # Build the EFI executable if the stub is available
  for stubdir in /usr/lib/systemd/boot/efi /usr/lib/gummiboot; do
    [ -r "${stubdir}/linuxx64.efi.stub" ] || continue
    sed -e 's/Enabled:.*/Enabled: true/' -i /etc/zfsbootmenu/config.yaml
    break
  done

  case "${INITCPIO,,}" in
    yes|y|on|1)
      sed -e "s/InitCPIO:.*/InitCPIO: true/" -i /etc/zfsbootmenu/config.yaml
      ;;
    no|n|off|0)
      sed -e "s/InitCPIO:.*/InitCPIO: false/" -i /etc/zfsbootmenu/config.yaml
      ;;
  esac
fi

case "${SKIP_ZBM_HOOKS,,}" in
  yes|y|on|true|1) exit 0 ;;
esac

zbm_hook_root=/etc/zfsbootmenu/hooks
mkdir -p "${zbm_hook_root}"

cat > "${zbm_hook_root}/echo-hook.sh" <<-'EOF'
	#/bin/sh
	
	if [ -r /lib/kmsg-log-lib.sh ] && . /lib/kmsg-log-lib.sh; then
		zinfo "running hook $0"
		exit
	fi

	echo "$0"
	sleep 2
	EOF

chmod 755 "${zbm_hook_root}/echo-hook.sh"

for hookdir in early-setup.d setup.d load-key.d boot-sel.d teardown.d; do
  mkdir -p "${zbm_hook_root}/${hookdir}"
  ln -Tsf ../echo-hook.sh "${zbm_hook_root}/${hookdir}/00-echo-hook.sh"
done

if [ -w /etc/zfsbootmenu/mkinitcpio.conf ]; then
  echo "zfsbootmenu_hook_root='${zbm_hook_root}'" >> /etc/zfsbootmenu/mkinitcpio.conf
fi

if [ -d /etc/zfsbootmenu/dracut.conf.d ]; then
  echo "zfsbootmenu_hook_root='${zbm_hook_root}'" \
    > /etc/zfsbootmenu/dracut.conf.d/hooks.conf
fi

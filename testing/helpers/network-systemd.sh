#!/bin/sh
# vim: softtabstop=2 shiftwidth=2 expandtab

# Enable systemd network configuration
mkdir -p /etc/systemd/network
cat << EOF >> /etc/systemd/network/20-wired.network
[Match]
Name=en*
[Network]
DHCP=yes
EOF

systemctl enable systemd-networkd.service || true

# Enable system resolver
rm -f /etc/resolv.conf
systemctl enable systemd-resolved.service || true
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Enable root login over ssh with a password
if [ -f /etc/ssh/sshd_config ]; then
  sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  systemctl enable sshd.service || true
fi

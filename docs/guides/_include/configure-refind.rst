.. parsed-literal::

  refind-install
  rm /boot/refind_linux.conf

  cat << EOF > /boot/efi/EFI/zbm/refind_linux.conf
  "Boot default"  "quiet loglevel=0 zbm.skip"
  "Boot to menu"  "quiet loglevel=0 zbm.show"
  EOF

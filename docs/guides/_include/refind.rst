Install and Configure rEFInd (optional)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

rEFInd provides a convenient way to dynamical choose between multiple operating systems or, for recovery, prior versions
of ZFSBootMenu images. It is also possible to
:doc:`create and directly boot a bundled UEFI executable for ZFSBootMenu </general/uefi-booting>`.

rEFInd should automatically identify ``/boot/efi`` as your EFI partition and install itself accordingly::

  xbps-install -S refind
  refind-install
  rm /boot/refind_linux.conf

Create ``/boot/efi/EFI/void/refind_linux.conf``::

  cat << EOF > /boot/efi/EFI/void/refind_linux.conf
  "Boot default"  "quiet loglevel=0 zbm.skip"
  "Boot to menu"  "quiet loglevel=0 zbm.show"
  EOF

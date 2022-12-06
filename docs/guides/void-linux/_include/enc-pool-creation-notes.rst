It's out of the scope of this guide to cover all of the pool creation options used - feel free to tailor them to suit
your system. However, the following options need to be addressed:

* ``encryption=aes-256-gcm`` - You can adjust the algorithm as you see fit, but this will likely be the most performant
  on modern x86_64 hardware.
* ``keylocation=file:///etc/zfs/zroot.key`` - This sets our pool encryption passphrase to the file
  ``/etc/zfs/zroot.key``, which we created in a previous step. This file will live inside your initramfs stored *on* the
  ZFS boot environment.
* ``keyformat=passphrase`` - By setting the format to ``passphrase``, we can now force a prompt for this in
  ``zfsbootmenu``. It's critical that your passphrase be something you can type on your keyboard, since you will need to
  type it in to unlock the pool on boot.

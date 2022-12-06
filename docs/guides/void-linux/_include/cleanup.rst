Exit the chroot, unmount everything
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  exit
  umount -n /mnt/{dev/pts,dev,sys,proc}
  umount /mnt/boot/efi

Export the zpool and reboot
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  zpool export zroot
  reboot

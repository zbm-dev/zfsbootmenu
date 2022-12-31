Exit the chroot, unmount everything
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  exit
  umount -n -R /mnt

Export the zpool and reboot
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  zpool export zroot
  reboot

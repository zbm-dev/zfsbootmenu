Prepare for first boot
----------------------

Exit the chroot, unmount everything
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  exit

.. code-block::

   cut -f2 -d" " /proc/mounts | grep ^/mnt | tac | while read i; do umount -l $i; done

Export the zpool and reboot
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  zpool export zroot
  reboot

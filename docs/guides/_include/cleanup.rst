Prepare for first boot
----------------------

Exit the chroot, unmount everything
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  exit

.. code-block::

  umount -n -R /mnt

Export the zpool and reboot
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  zpool export zroot
  reboot

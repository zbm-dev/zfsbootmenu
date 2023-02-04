Create a ``vfat`` filesystem
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  mkfs.vfat -F32 "$BOOT_DEVICE"

Create an fstab entry and mount
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  cat << EOF >> /etc/fstab
  $BOOT_DEVICE /boot/efi vfat defaults 0 0
  EOF

  mkdir -p /boot/efi
  mount /boot/efi

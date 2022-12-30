Create a ``vfat`` filesystem
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. parsed-literal::

  mkfs.vfat -F32 |esp_part_full|

Create an fstab entry and mount
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. parsed-literal::

  cat << EOF >> /etc/fstab
  $( blkid | grep |esp_part_full| | cut -d ' ' -f 2 ) /boot/efi vfat defaults 0 0
  EOF

  mkdir /boot/efi
  mount /boot/efi

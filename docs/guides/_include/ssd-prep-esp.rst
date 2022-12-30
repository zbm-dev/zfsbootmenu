Create ESP partition 
~~~~~~~~~~~~~~~~~~~~

.. parsed-literal::

  sgdisk -n\ |esp_part_no|:1m:+512m -t\ |esp_part_no|:ef00 |esp_disk|

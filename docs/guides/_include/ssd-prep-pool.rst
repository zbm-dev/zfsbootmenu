Create zpool partition 
~~~~~~~~~~~~~~~~~~~~~~

.. parsed-literal::

  sgdisk -n\ |pool_part_no|:0:0 -t\ |pool_part_no|:bf00 |pool_disk|

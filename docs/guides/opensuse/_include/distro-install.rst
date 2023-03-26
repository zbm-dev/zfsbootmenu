Install Leap 
------------

Enable software repositories
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash
  
  zypper --root /mnt ar https://download.opensuse.org/distribution/leap/$(lsb_release -rs)/repo/non-oss non-oss
  zypper --root /mnt ar https://download.opensuse.org/distribution/leap/$(lsb_release -rs)/repo/oss oss
  zypper --root /mnt ar https://download.opensuse.org/update/leap/$(lsb_release -rs)/oss update-oss
  zypper --root /mnt ar https://download.opensuse.org/update/leap/$(lsb_release -rs)/non-oss update-nonoss
  zypper --root /mnt ar https://download.opensuse.org/repositories/filesystems/$(lsb_release -rs)/filesystems.repo
  zypper --root /mnt refresh

.. note::

  Enter **a** to always trust the key.

Add base packages
~~~~~~~~~~~~~~~~~

.. code-block:: bash

	zypper --root /mnt install -t pattern enhanced_base

Add package management
~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

	zypper --root /mnt install zypper yast2

Copy files into the new install
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Unencrypted

    .. code-block:: bash

      rm /mnt/etc/resolv.conf
      cp -L /etc/resolv.conf /mnt/etc
      cp /etc/hostid /mnt/etc

  .. group-tab:: Encrypted

    .. code-block:: bash

      rm /mnt/etc/resolv.conf
      cp /etc/hostid /mnt/etc
      cp -L /etc/resolv.conf /mnt/etc
      mkdir -p /mnt/etc/zfs
      cp /etc/zfs/zroot.key /mnt/etc/zfs

Chroot into the new OS
~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  mount -t proc proc /mnt/proc
  mount -t sysfs sys /mnt/sys
  mount -B /dev /mnt/dev
  mount -t devpts pts /mnt/dev/pts
  chroot /mnt /bin/bash

Basic system configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  update-ca-certificates
  echo 'LANG=en_US.UTF-8' > /etc/locale.conf
  echo 'YOURHOSTNAME' > /etc/hostname
  echo -e '127.0.1.1\tYOURHOSTNAME' >> /etc/hosts
  passwd

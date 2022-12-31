Install Debian
--------------

.. code-block:: bash

  debootstrap bullseye /mnt

Copy files into the new install
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Encrypted

    .. code-block:: bash

      cp /etc/hostid /mnt/etc/hostid
      cp /etc/resolv.conf /mnt/etc/
      mkdir -p /mnt/etc/zfs
      cp /etc/zfs/zroot.key /mnt/etc/zfs/

  .. group-tab:: Unencrypted

    .. code-block:: bash

      cp /etc/hostid /mnt/etc/hostid
      cp /etc/resolv.conf /mnt/etc

Chroot into the new OS
~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  mount -t proc proc /mnt/proc
  mount -t sysfs sys /mnt/sys
  mount -B /dev /mnt/dev
  mount -t devpts pts /mnt/dev/pts
  chroot /mnt /bin/bash

Basic Debian Configuration
--------------------------

Set a hostname
~~~~~~~~~~~~~~

.. code-block:: bash

  echo 'YOURHOSTNAME' > /etc/hostname
  echo -e '127.0.1.1\tYOURHOSTNAME' >> /etc/hosts

Set a root password
~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  passwd

Configure ``apt``. Use other mirrors if you prefer.

.. code-block:: bash

  cat <<EOF > /etc/apt/sources.list
  deb http://deb.debian.org/debian bullseye main contrib
  deb-src http://deb.debian.org/debian bullseye main contrib

  deb http://deb.debian.org/debian-security/ bullseye-security main contrib
  deb-src http://deb.debian.org/debian-security/ bullseye-security main contrib

  deb http://deb.debian.org/debian bullseye-updates main contrib
  deb-src http://deb.debian.org/debian bullseye-updates main contrib

  deb http://deb.debian.org/debian bullseye-backports main contrib
  deb-src http://deb.debian.org/debian bullseye-backports main contrib
  EOF

Update the repository cache
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  apt update

Install additional base packages
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  apt install locales keyboard-configuration console-setup

Configure packages to customize local and console properties
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  dpkg-reconfigure locales tzdata keyboard-configuration console-setup

.. note::

  You should always enable the `en_US.UTF-8` locale because some programs require it.

Install Ubuntu
--------------

.. code-block:: bash

  debootstrap jammy /mnt

Copy files into the new install
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Unencrypted

    .. code-block:: bash

      cp /etc/hostid /mnt/etc
      cp /etc/resolv.conf /mnt/etc

  .. group-tab:: Encrypted

    .. code-block:: bash

      cp /etc/hostid /mnt/etc/hostid
      cp /etc/resolv.conf /mnt/etc/
      mkdir /mnt/etc/zfs
      cp /etc/zfs/zroot.key /mnt/etc/zfs

Chroot into the new OS
~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  mount -t proc proc /mnt/proc
  mount -t sysfs sys /mnt/sys
  mount -B /dev /mnt/dev
  mount -t devpts pts /mnt/dev/pts
  chroot /mnt /bin/bash

Basic Ubuntu Configuration
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
  # Uncomment the deb-src entries if you need source packages

  deb http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
  # deb-src http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse

  deb http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
  # deb-src http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse

  deb http://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
  # deb-src http://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse

  deb http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse
  # deb-src http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse

  deb http://archive.canonical.com/ubuntu/ jammy partner
  # deb-src http://archive.canonical.com/ubuntu/ jammy partner
  EOF

Update the repository cache and system
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  apt update
  apt upgrade

Install additional base packages
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  apt install --no-install-recommends linux-generic locales keyboard-configuration console-setup

.. note::
  The `--no-install-recommends` flag is used here to avoid installing recommended, but not strictly needed, packages
  (including `grub2`).

Configure packages to customize local and console properties
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

  dpkg-reconfigure locales tzdata keyboard-configuration console-setup

.. note::

  You should always enable the `en_US.UTF-8` locale because some programs require it.

.. seealso::

  Any additional software should be selected and installed at this point. A basic debootstrap installation is very
  limited, lacking several packages that might be expected from an interactive installation.

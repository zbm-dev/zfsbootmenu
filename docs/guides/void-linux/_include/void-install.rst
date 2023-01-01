Install Void
------------

Adjust the mirror, libc, and package selection as you see fit.

.. code-block::

  XBPS_ARCH=x86_64 xbps-install \
    -S -R https://mirrors.servercentral.com/voidlinux/current \
    -r /mnt base-system

Copy our files into the new install
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Encrypted

    .. code-block::

      cp /etc/hostid /mnt/etc
      mkdir /mnt/etc/zfs
      cp /etc/zfs/zroot.key /mnt/etc/zfs

  .. group-tab:: Unencrypted

    .. code-block::

      cp /etc/hostid /mnt/etc
      cp /etc/resolv.conf /mnt/etc/

Chroot into the new OS
~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  xchroot /mnt

Basic Void configuration
------------------------

Set the keymap, timezone and hardware clock
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  cat << EOF >> /etc/rc.conf
  KEYMAP="us"
  HARDWARECLOCK="UTC"
  EOF
  ln -sf /usr/share/zoneinfo/<timezone> /etc/localtime

Configure your glibc locale
~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. note::

  This does not need to be done on musl, as musl does not have system locale support.

.. code-block::

  cat << EOF >> /etc/default/libc-locales
  en_US.UTF-8 UTF-8
  en_US ISO-8859-1
  EOF
  xbps-reconfigure -f glibc-locales

Set a root password
~~~~~~~~~~~~~~~~~~~

.. code-block::

  passwd

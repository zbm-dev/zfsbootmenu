Create our initial file systems
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. parsed-literal::

  zfs create -o mountpoint=none zroot/ROOT
  zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/\ |distribution|
  zfs create -o mountpoint=/home zroot/home

  zpool set bootfs=zroot/ROOT/\ |distribution| zroot

.. note::

  It is important to set the property ``canmount=noauto`` on any file systems with ``mountpoint=/`` (that is, on
  any additional boot environments you create). Without this property, the OS will attempt to automount all ZFS file
  systems and fail when multiple file systems attempt to mount at ``/``; this will prevent your system from booting.
  Automatic mounting of ``/`` is not required because the root file system is explicitly mounted in the boot process.

  Also note that, unlike many ZFS properties, ``canmount`` is not inheritable. Therefore, setting ``canmount=noauto`` on
  ``zroot/ROOT`` is not sufficient, as any subsequent boot environments you create will default to ``canmount=on``. It is
  necessary to explicitly set the ``canmount=noauto`` on every boot environment you create.

Export, then re-import with a temporary mountpoint of ``/mnt``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Encrypted

    .. parsed-literal::

      zpool export zroot
      zpool import -N -R /mnt zroot
      zfs load-key -L prompt zroot
      zfs mount zroot/ROOT/\ |distribution|
      zfs mount zroot/home

  .. group-tab:: Unencrypted

    .. parsed-literal::

      zpool export zroot
      zpool import -N -R /mnt zroot
      zfs mount zroot/ROOT/\ |distribution|
      zfs mount zroot/home

Verify that everything is mounted correctly
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. parsed-literal::

  # **mount | grep mnt**
  zroot/ROOT/\ |distribution| on /mnt type zfs (rw,relatime,xattr,posixacl)
  zroot/home on /mnt/home type zfs (rw,relatime,xattr,posixacl)

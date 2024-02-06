Native Encryption
=================

ZFSBootMenu can import pools or filesystems with native encryption enabled. If your boot environments are not encrypted
but, for example, ``/home`` is, you will not receive a decryption prompt during boot. To ensure that you can decrypt
your pool to load the kernel and initramfs, you'll need to you have the filesystem parameters configured correctly.

It's critical that ``keyformat`` is set to ``passphrase``, otherwise you'll be unable to enter the correct value in the
bootloader. OpenZFS currently supports only one key, but in a way which ZFSBootMenu can exploit: if you configure the
``keylocation`` value to a file on disk, put your passphrase in that, and then include that file into the FINAL
initramfs (the one in the ``/boot`` subdirectory of your encrypted root), you won't receive a second password prompt on
boot. When ZFSBootMenu attempts to unlock root filesystems, it will override any ``file://`` URI it encounters as a
``keylocation`` if that file is not accessible from within the bootloader image. This allows ZFSBootMenu to prompt for
passphrases when necessary.

.. note::

  **Never** place encryption keys inside a custom ZFSBootMenu image! The ZFSBootMenu image will typically be installed
  on an unencrypted partition with minimal or no access restrictions. If an encryption key is placed in such a location,
  anybody with access to the system will be able to read your passphrase.

As an example, Consider a filesystem layout such as::

  zfs get all zroot | egrep '(encryption|keylocation|keyformat)'
  zroot  encryption            aes-256-gcm                -
  zroot  keylocation           file:///etc/zfs/zroot.key  local
  zroot  keyformat             passphrase                 -
  zroot  encryptionroot        zroot                      -

On systems that use ``dracut``, the key for ``zroot`` can be added to initramfs images by running::

  echo 'install_items+=" /etc/zfs/zroot.key "' > /etc/dracut.conf.d/zfs-keys.conf

For ``mkinitcpio``, add the key to the ``FILES`` array in ``mkinitcpio.conf``::

  echo 'FILES+=(/etc/zfs/zroot.key)' >> /etc/mkinitcpio.conf

.. note::

  When adding encryption keys to initramfs images, **always ensure** that the resulting images are not readable by any
  user other than root. Recent versions of ``dracut`` and ``mkinitcpio`` ensure this by default with umask of ``0077``.
  Users with read access to your initramfs image will be able to read your ZFS key file even if it has mode ``000`` in
  the image; always confirm for your self that the initramfs is protected!

For convenience, ZFSBootMenu recognizes the ZFS property ``org.zfsbootmenu:keysource`` as the name of a filesystem that
should be searched for ZFS key files. When a boot environment specifies a ``file://`` URI as its ``keylocation``,
ZFSBootMenu will attempt to mount a filesystem indicated by the ``org.zfsbootmenu:keysource`` property (if it exists)
and search for the named ``keylocation`` therein. If found, ZFSBootMenu will copy the key into a cache within the
in-memory root filesystem so that subsequent operations that require reloading the key (for example, changing the
default boot environment or cloning a snapshot) will not prompt the user for passphrases.

When searching for a ``keylocation`` relative to the filesystem named by ``org.zfsbootmenu:keysource``, ZFSBootMenu will
first try to strip the ``mountpoint`` of the keysource filesystem from any ``keylocation`` URI that references the keys
to map the ``keylocation`` that would be observed on a running system to the proper location in the keysource. For
example, if the running system is set up so that ``zroot`` is the ``encryptionroot`` for all filesystems on a pool,
running the commands::

  zfs create -o mountpoint=/etc/zfs/keys zroot/keystore
  echo "MySecretPassphrase" > /etc/zfs/keys/zroot.key
  chmod 000 /etc/zfs/keys/zroot.key
  zfs set keylocation=file:///etc/zfs/keys/zroot.key zroot
  zfs set org.zfsbootmenu:keysource=zroot/keystore zroot
  echo 'install_optional_items+=" /etc/zfs/keys/zroot.key "' >> /etc/dracut.conf.d/zol.conf

will cause ZFSBootMenu to attempt to cache the key ``file:///etc/zfs/keys/zroot.key`` from ``zroot/keystore`` when
unlocking the ``zroot`` pool. Because ``zroot/keystore`` specifies ``mountpoint=/etc/zfs/keys``, ZFSBootMenu will first
try to strip ``/etc/zfs/keys`` from the ``keylocation`` URI, looking for the file ``zroot.key`` at the root of the
filesystem ``zroot/keystore``. If this fails, ZFSBootMenu will fall back to the full path, looking for
``etc/zfs/keys/zroot.key`` within the keysource filesystem. If either location is found, ZFSBootMenu will retain a cache
of the key should it be needed to unlock the pool again.

..
  vim: softtabstop=2 shiftwidth=2 textwidth=120

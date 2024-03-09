Migration from GRUB
===================

While GRUB has very different requirements for filesystem layout, it is possible
to migrate from GRUB to ZFSBootMenu.

First, create a :doc:`portable installation </general/portable>` that will let
you boot from a USB drive. This should give you all the tools you need to migrate
``/boot`` into the root filesystem in such a way that ZFSBootMenu will recognize
your boot environment. Af first, ZFSBootMenu will probably fail to recognize any
boot environments and try dropping you into a recovery shell. Assuming your root
filesystem is ``rpool/ROOT/debian`` and your boot filesystem is ``bpool/BOOT/debian``,
you should be able to:

1. Confirm that ``bpool`` and ``rpool`` are both imported. If not, you can manually
   import each pool, or you can try running ``/libexec/zfunc import_pool`` which will
   try to import both.
2. Make sure the pools are writable::

    set_rw_pool rpool
    set_rw_pool bpool

4. Use the ``mount_zfs`` helper to mount both the boot and root filesystems::

    mount_zfs bpool/BOOT/debian
    allow_rw=yes mount_zfs rpool/ROOT/debian

   each call will print the path where the filesystem is mounted, which (in this
   case) will be, respectively::

    /zfsbootmenu/environments/bpool/BOOT/debian/mnt
    /zfsbootmenu/environments/rpool/ROOT/debian/mnt

5. Copy the contents of the boot filesystem to the ``boot`` subdirectory of the root::

    cd /zfsbootmenu/environments/bpool/BOOT/debian/mnt
    mkdir -p /zfsbootmenu/environments/rpool/ROOT/debian/mnt/boot
    cp -a . /zfsbootmenu/environments/rpool/ROOT/debian/mnt/boot

6. Make sure the boot pool won't be mounted at next boot::

    zfs set canmount=noauto bpool/BOOT/debian

7. Exit the recovery shell. You should now see your environment in the menu.

After confirming this works, you can now install ZFSBootMenu in your EFI System Partition
and add it to the boot order with ``efibootmgr`` (or use a bootloader like ``rEFInd`` to load it).

Once everything works, you can destroy your ``bpool`` and remove GRUB from the ESP if you so choose.

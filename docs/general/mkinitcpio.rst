Building with mkinitcpio
========================

ZFSBootMenu also supports the `mkinitcpio <https://gitlab.archlinux.org/archlinux/mkinitcpio/mkinitcpio/>`_ initramfs
generator used by Arch Linux and available for Void Linux, but it must be configured first.

Since `version 2.0.0 <https://github.com/zbm-dev/zfsbootmenu/releases/tag/v2.0.0>`_, ZFSBootMenu will install a standard
:zbm:`mkinitcpio.conf <etc/zfsbootmenu/mkinitcpio.conf>` in the ``/etc/zfsbootmenu`` configuration directory. This file
is generally the same as a standard ``mkinitcpio.conf``, except some additional declarations may be added to control
aspects of the ``zfsbootmenu`` mkinitcpio module. The configuration file includes extensive inline documentation in the
form of comments; configuration options specific to ZFSBootMenu are also described in the
:ref:`zfsbootmenu(7) <zbm-mkinitcpio-options>` manual page.

ZFSBootMenu still expects to use Dracut by default. To override this behavior and instead use mkinitcpio, edit
``/etc/zfsbootmenu/config.yaml`` and add the following options:

.. code-block:: yaml

  Global:
    InitCPIO: true
    ## NOTE: The following three lines are OPTIONAL
    InitCPIOHookDirs:
      - /etc/zfsbootmenu/initcpio
      - /usr/lib/initcpio

.. note::

  In some ZFSBootMenu guides, like :doc:`remote-access`, some mkinitcpio modules will be installed to
  ``/etc/zfsbootmenu/initcpio`` to keep them isolated from system-installed modules. To accommodate this non-standard
  installation, ``InitCPIOHookDirs`` must be defined in ``/etc/zfsbootmenu/config.yaml``. Furthermore, because
  overriding the hook directory causes mkinitcpio to ignore its default module path, the default ``/usr/lib/initcpio``
  must be manually specified. If all hooks are installed in ``/usr/lib/initcpio`` or ``/etc/initcpio``, the ZFSBootMenu
  configuration does **not** need to specify ``InitCPIOHookDirs``.

Without further changes, running ``generate-zbm`` should now produce a ZBM image based on mkinitcpio rather than Dracut.

Whenever ``generate-zbm`` is run to generate images based on mkinitcpio, it forcefully adds the the required
``zfsbootmenu`` hook after any hooks defined in the ``HOOKS`` array of ``/etc/zfsbootmenu/mkinitcpio.conf``. The default
configuration file explicitly includes the ``zfsbootmenu`` hook in the array as a visual reminder that it will be
included (strictly speaking, this will cause mkinitcpio to add the hook **twice**, but because the ``zfsbootmenu`` hook
completely takes over execution of its initramfs image, it will only ever run once). If any custom configuration requires
additional hooks be added to the ZFSBootMenu initramfs image, make sure that these hooks are included **before** any
occurrence of ``zfsbootmenu`` in ``HOOKS``. Better still, just remove the ``zfsbootmenu`` hook from
``/etc/zfsbootmenu/mkinitcpio.conf`` when making any edits to ``HOOKS`` to minimize the chance of configuration errors.

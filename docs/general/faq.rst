Frequently Asked Questions
==========================

.. contents:: Contents
  :depth: 2
  :local:
  :backlinks: none

Why don't the installation guides contain <X>?
----------------------------------------------

ZFSBootMenu's installation guides are designed to cover the general procedure
for installing Linux with ZFS as the root filesystem and ZFSBootMenu as the
bootloader.

The guides can easily accomodate multi-disk pools by modifying the pool creation
arguments as described in :manpage:`zpool-create(8)`.

Additional packages and configuration can be added at your choice. Consult your
distribution's documentation for more information.

How can I send a snapshot to ZFSBootMenu?
-----------------------------------------

Sending a snapshot to ZFSBootMenu is one way to bootstrap a new system, or restore
from a backup. This can be done using :manpage:`zfs-send(8)`, :manpage:`zfs-recv(8)`,
and :manpage:`mbuffer`, which are all available in the published :ref:`recovery-images`.

Why doesn't ZFSBootMenu support having a separate pool for ``/boot``?
---------------------------------------------------------------------

Why can't my computer boot ZFSBootMenu?
---------------------------------------

How can I get more information from ZFSBootMenu for debugging?
--------------------------------------------------------------

What's with this hostid stuff?
------------------------------

What ZFS features does ZFSBootMenu support?
-------------------------------------------

How can I edit ZFSBootMenu's kernel commandline?
------------------------------------------------

How can I edit my boot environment's kernel commandline?
--------------------------------------------------------

How can I boot ZFSBootMenu via PXE/netboot?
-------------------------------------------

Why doesn't ZFSBootMenu support <X> or have <X> feature?
--------------------------------------------------------

Maybe we haven't thought of it yet, maybe we don't want the feature. Maybe something
else. First, search the `issue tracker <https://github.com/zbm-dev/zfsbootmenu/issues>`_
and `discussions <https://github.com/zbm-dev/zfsbootmenu/discussions>`_, then
you can create a new `feature request <https://github.com/zbm-dev/zfsbootmenu/discussions/new?category=feature-requests>`_
or bring it up on IRC (``#zfsbootmenu`` on ``irc.libera.chat``).

How can I get support for ZFSBootMenu?
--------------------------------------

First, search the `issue tracker <https://github.com/zbm-dev/zfsbootmenu/issues>`_
and `discussions <https://github.com/zbm-dev/zfsbootmenu/discussions>`_. If your
questions are not answered, you can create a new
`discussion <https://github.com/zbm-dev/zfsbootmenu/discussions/new?category=questions>`_
or ask on IRC (``#zfsbootmenu`` on ``irc.libera.chat``).


Why is ZFSBootMenu written in bash and not a real language?
-----------------------------------------------------------

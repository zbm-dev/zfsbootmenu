Tailscale Integration
=====================

Sometimes direct remote access to ZFSBootMenu is not possible, like when a computer using ZFSBootMenu is behind a
firewall or inside a private network. Adding `Tailscale <https://tailscale.com>`_ support to ZFSBootMenu can help
bridge this gap.

Prerequisites
-------------

Presently, the only known and recommended initramfs module for Tailscale integration is
`mkinitcpio-tailscale <https://github.com/classabbyamp/mkinitcpio-tailscale>`_, so this guide requires using
:doc:`mkinitcpio <mkinitcpio>` to generate the ZFSBootMenu image.

:doc:`Remote access <remote-access>` should also be set up before following this guide, though the SSH server can
be either Dropbear from that guide or `Tailscale's built-in SSH server <https://tailscale.com/kb/1193/tailscale-ssh/>`_.
Note that if using Tailscale's SSH server, remote access will only be possible via Tailscale, not the local network.

Because the Tailscale node key is stored in the initramfs, it should not use the same one as the host system. To ensure
this key is useless to anyone trying to access the connected Tailnet,
`Tailscale ACLs <https://tailscale.com/kb/1018/acls/>`_ should be used to restrict any ZFSBootMenu Tailscale nodes
from connecting to any other node in the Tailnet. For example:

.. code-block:: json

  // Example ACLs for mkinitcpio-tailscale and ZFSBootMenu
  {
    "tagOwners": {
      "tag:zfsbootmenu": ["autogroup:admin"],
      "tag:local":      ["autogroup:admin"],
    },

    "acls": [
      {"action": "accept", "src": ["tag:local"], "dst": ["*:*"]},
    ],
  }

In this example, nodes with ``tag:local`` can connect to any node in the Tailnet, but because there is no rule with
``tag:zfsbootmenu`` as the source, it cannot initiate any connections, rendering it fairly useless if compromised.

Setup
-----

First, generate an `auth key <https://login.tailscale.com/admin/settings/keys>`_ and save it to ``/tmp/zbm-ts-authkey``.
The recommended settings for this key are:

- **not** reusable
- **1 day** expiration
- **not** ephemeral
- tagged with the relevant ACL tag (``tag:zfsbootmenu`` if using ACLs like the example above)

Once used to generate the necessary information, this key is no longer needed and can be revoked or expired safely.

Next, install `mkinitcpio-tailscale <https://github.com/classabbyamp/mkinitcpio-tailscale>`_. This is available as a
package on Void Linux. If not available as a package, it can be installed manually::

  curl -L https://github.com/classabbyamp/mkinitcpio-tailscale/archive/master.tar.gz | tar -zxvf - -C /tmp
  mkdir -p /etc/zfsbootmenu/initcpio/{install,hooks}
  cp /tmp/mkinitcpio-tailscale-master/tailscale_hook /etc/zfsbootmenu/initcpio/hooks/tailscale
  cp /tmp/mkinitcpio-tailscale-master/tailscale_install /etc/zfsbootmenu/initcpio/install/tailscale
  rm -r /tmp/mkinitcpio-tailscale-master

To generate the node key for ZFSBootMenu's Tailscale node::

  mkinitcpio-tailscale-setup -k /tmp/zbm-ts-authkey

Once it runs successfully, you should see a machine in the
`Tailscale admin console <https://login.tailscale.com/admin/machines>`_ with the name ``<your hostname>-mkinitcpio``
and the ACL tag ``tag:zfsbootmenu``.

Then, enable the ``tailscale`` module in ``/etc/zfsbootmenu/mkinitcpio.conf`` by manually appending ``tailscale`` to
the ``HOOKS`` array, or by running::

  sed -e '/HOOKS.*dropbear/a HOOKS+=(tailscale)' -i /etc/zfsbootmenu/mkinitcpio.conf

If using Tailscale SSH instead of Dropbear, add the necessary flags to ``/etc/tailscale/tailscaled.conf``::

  tailscale_args="--ssh"

With the above configuration complete, running ``generate-zbm`` should produce a ZFSBootMenu image that contains the
necessary components to enable SSH access over Tailscale in your bootloader.

After rebooting, ZFSBootMenu should configure the network interface, launch an SSH server, and connect to Tailscale.
Connection to ZFSBootMenu should be possible using either the local IP (if using Dropbear), Tailscale IP, or Tailscale
hostname.

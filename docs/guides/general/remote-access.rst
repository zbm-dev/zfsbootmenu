Remote Access to ZFSBootMenu
============================

.. contents:: Contents
  :depth: 2
  :local:
  :backlinks: none

Having SSH access to ZFSBootMenu can be critical because it allows some measure of recovery over a remote connection. If
your boot environments reside in encrypted filesystems, SSH access is necessary if you ever intend to reboot a machine
when you are not physically present. Because ZFSBootMenu supports Dracut and mkinitcpio, any mechanism that can provide
remote access to a Dracut or mkinitcpio initramfs will work.

Dracut
------

The `dracut-crypt-ssh <https://github.com/dracut-crypt-ssh/dracut-crypt-ssh>`_ provides a straightforward approach to
configuring and launching an SSH server in Dracut images. The module is packaged in Void and does not rely on
``systemd`` within the initramfs. If you run a distribution that does not package ``dracut-crypt-ssh``, you will need to
track down its dependencies. The ``dracut-network`` module and ``dropbear`` are required to provide network access and
an SSH server, respectively; other prerequisites are probably already installed on your system.

Simplified Installation Instructions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The ``dracut-crypt-ssh`` package comes with a few helper utilities in the ``module/60crypt-ssh/helper`` directory that
are designed to simplify providing passwords and snooping console output so that you can interact with unlock processes
that are already running in the initramfs. These components are not required for ZFSBootMenu and do not provide a lot of
value. If you have no problems installing the package as intended, it is OK to leave the helpers installed. If your
distribution has trouble compiling the helpers, just copy the contents of the ``60crypt-ssh`` directory, less the
``helper`` directory and ``Makefile``, to the modules directory for Dracut. This will most likely be
``/usr/lib/dracut/modules.d/60crypt-ssh``.

If you do not install the contents of ``helper``, you may wish to edit the ``module-setup.sh`` script provided by the
package to remove references to installing the helper. At the time of writing, these references consist of the last four
lines (five, if you count the harmless comment) of the ``install()`` functioned. Removing these lines should not be
critical, as Dracut should happily continue the initramfs creation process even if those installation commands fail.

If you use Dracut to produce the initramfs images in your boot environment, you may wish to disable the ``crypt-ssh``
module in those images. Just add

.. code-block::

  omit_dracutmodules+=" crypt-ssh "

to a configuration file in ``/etc/dracut.conf.d``. The configuration file must have a ``.conf`` extension to be
recognized; see `dracut.conf(5) <https://man.voidlinux.org/dracut.conf.5>`_ for more information.

Configuring Dropbear in ZFSBootMenu
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

By default, ``dracut-crypt-ssh`` will generate random host keys for your ZFSBootMenu initramfs. This is undesirable
because SSH will complain about unknown keys every time you reboot. If you wish, you can configure the module to copy
your regular host keys into the image. However, there are two problems with this:

1. The ZFSBootMenu image will generally be installed on a filesystem with no access permissions, allowing anybody to
   read your private host keys; and

2. The ``dropbearconvert`` program may be incapable of converting modern OpenSSH host keys into the required dropbear
   format.

To create dedicated host keys in the proper format, decide on a location, for example ``/etc/dropbear``, and create the
new keys::

  mkdir -p /etc/dropbear
  ssh-keygen -t rsa -m PEM -f /etc/dropbear/ssh_host_rsa_key
  ssh-keygen -t ecdsa -m PEM -f /etc/dropbear/ssh_host_ecdsa_key

The module expects to install RSA and ECDSA keys, so both types are created here.

.. note::

  When prompted for a passphrase when creating each host key, leave it blank. A non-empty password will prevent dropbear
  from reading a key.

To inform ``dracut-network`` that it must bring up a network interface, pass the kernel command-line parameters
``ip=dhcp`` and ``rd.neednet=1`` to your ZFSBootMenu image. If you use another boot loader to start ZFSBootMenu, *e.g.*
rEFInd or syslinux, this can be accomplished by configuring that loader. However, it may be more convenient to add these
parameters directly to the ZFSBootMenu image::

  mkdir -p /etc/cmdline.d
  echo "ip=dhcp rd.neednet=1" > /etc/cmdline.d/dracut-network.conf

It is possible to specify a static IP configuration by replacing ``dhcp`` with a properly formatted configuration
string. Consult the `dracut documentation <https://man.voidlinux.org/dracut.cmdline.7#Network>`_ for details about
static IP configuration.

There are methods besides writing to ``/etc/cmdline.d`` or configuring another boot loader to specify kernel
command-line arguments that will configure networking in Dracut. However, Dracut uses the ``/etc/cmdline.d`` directory
to store "fake" arguments, which it processes directly rather than handing to the kernel. In my tests, using other
methods (like adding these arguments to the ``kernel_cmdline`` Dracut option for a UEFI bundle) can cause the
``ip=dhcp`` argument to appear more than once on the kernel command-line, which may cause ``dracut-network`` to fail
catastrophically and refuse to boot. Writing a configuration file in ``/etc/cmdline.d`` is a reliable way to ensure that
``ip=dhcp`` appears exactly once to ``dracut-network``.

With critical pieces in place, ZFSBootMenu can be configured to bundle ``dracut-crypt-ssh`` in its images. Create the
Dracut configuration file ``/etc/zfsbootmenu/dracut.conf.d/dropbear.conf`` with the following contents::

  # Enable dropbear ssh server and pull in network configuration args
  add_dracutmodules+=" crypt-ssh "
  install_optional_items+=" /etc/cmdline.d/dracut-network.conf "
  # Copy system keys for consistent access
  dropbear_rsa_key=/etc/dropbear/ssh_host_rsa_key
  dropbear_ecdsa_key=/etc/dropbear/ssh_host_ecdsa_key
  # User zbmuser is the authorized unlocker here
  dropbear_acl=/home/zbmuser/.ssh/authorized_keys

The last line is optional and assumes the user ``zbmuser`` should provide an ``authorized_keys`` file that will
determine remote access to the ZFSBootMenu image. The ``dracut-crypt-ssh`` module does not allow for password
authentication over SSH; instead, key-based authentication is forced. By default, the list of authorized keys is taken
from ``/root/.ssh/authorized_keys`` on the host. If you would prefer to use the ``authorized_keys`` file from another
user on your system, copy the above example and replace ``zbmuser`` with the name of the user whose ``authorized_keys``
you wish to include.

.. note::

  The default configuration will start dropbear on TCP port 222. This can be overridden with the ``dropbear_port``
  configuration option. Generally, you do not want the server listening on the default port 22. Clients that expect to
  find your normal host keys when connecting to an SSH server on port 22 will refuse to connect when they find different
  keys provided by dropbear.

Unless you've taken steps not described here, the network-enabled ZFSBootMenu image will not advertise itself via
dynamic DNS or mDNS. You will need to know the IP address of the ZFSBootMenu host to connect. Thus, you should either
configure a static IP address in ``/etc/cmdline.d/dracut-network.conf`` or configure your DHCP server to reserve a known
address for the MAC address of the network interface you configure for ``dracut-crypt-ssh``.

mkinitcpio
----------

ZFSBootMenu also supports the `mkinitcpio <https://gitlab.archlinux.org/archlinux/mkinitcpio/mkinitcpio/>`_ initramfs
generator used by Arch Linux.

ZFSBootMenu Configuration Changes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Since `version 2.0.0 <https://github.com/zbm-dev/zfsbootmenu/releases/tag/v2.0.0>`_, ZFSBootMenu will install a standard
:zbm:`mkinitcpio.conf <etc/zfsbootmenu/mkinitcpio.conf>` in the ``/etc/zfsbootmenu`` configuration directory. This file
is generally the same as a standard ``mkinitcpio.conf``, except some additional declarations may be added to control
aspects of the ``zfsbootmenu`` mkinitcpio module. The configuration file includes extensive inline documentation in the
form of comments; configuration options specific to ZFSBootMenu are also described in the
:ref:`zfsbootmenu(7) <zbm-mkinitcpio-options>` manual page.

ZFSBootMenu still expects to use dracut by default. To override this behavior and instead use mkinitcpio, edit
``/etc/zfsbootmenu/config.yaml`` and add the following options:

.. code-block:: yaml

  Global:
    InitCPIO: true
    ## NOTE: The following three lines are OPTIONAL
    InitCPIOHookDirs:
      - /etc/zfsbootmenu/initcpio
      - /usr/lib/initcpio

.. note::

  In the examples below, a couple of mkinitcpio modules will be installed to ``/etc/zfsbootmenu/initcpio`` to keep them
  isolated from system-installed modules. To accommodate this non-standard installation, ``InitCPIOHookDirs`` must be
  defined in ``/etc/zfsbootmenu/config.yaml``. Furthermore, because overriding the hook directory causes mkinitcpio to
  ignore its default module path, the default ``/usr/lib/initcpio`` must be manually specified. If all hooks are
  installed in ``/usr/lib/initcpio`` or ``/etc/initcpio``, the ZFSBootMenu configuration does **not** need to specify
  ``InitCPIOHookDirs``.

Without further changes, running ``generate-zbm`` should now produce a ZBM image based on mkinitcpio rather than dracut,
although it will lack networking and remote-access capabilities. (By default, ``generate-zbm`` instructs mkinitcpio to
use the configuration at ``/etc/zfsbootmenu/config.yaml``, although this can be changed in the ``generate-zbm``
configuration file.) For these features, some additional mkinitcpio modules and configuration changes are necessary.

Because further configuration will require additional mkinitcpio modules, and these must be run before the
``zfsbootmenu`` module in the initramfs, edit ``/etc/zfsbootmenu/mkinitcpio.conf`` and **remove** any ``zfsbootmenu``
entry in the ``HOOKS`` definition. As the standard configuration file notes, the ``zfsbootmenu`` module is required for
ZFSBootMenu to function, but ``generate-zbm`` will forcefully at this at the end of the module list. Thus, the simplest
way to ensure that additions to the ``HOOKS`` array occur *before* the ``zfsbootmenu`` module is to omit the latter from
the configuration. The standard ``HOOKS`` line in ``/etc/zfsbootmenu/mkinitcpio.conf`` should therefore be something
like::

  HOOKS=(base udev autodetect modconf block filesystems keyboard)

Basic Network Access
~~~~~~~~~~~~~~~~~~~~

Network access in a mkinitcpio image can be realized in one of several ways. In Arch Linux, for example, the
`mkinitcpio-nfs-utils <https://archlinux.org/packages/?name=mkinitcpio-nfs-utils>`_ package provides a
`net module <https://wiki.archlinux.org/title/Mkinitcpio#Using_net>`_ that allows the initramfs to parse ``ip=``
directives from the kernel command line. When a static IP configuration is sufficient, the
`mkinitcpio-rclocal <https://github.com/ahesford/mkinitcpio-rclocal>`_ module allows user scripts to be injected at
several points in the initramfs boot process and provides a simple mechanism for configuring a network interface.

When installing mkinitcpio modules that are not provided by a system package manager, it may be preferable to keep them
isolated from the ordinary module tree. Because this module will only be required in ZBM images, placing extra modules
in ``/etc/zfsbootmenu/initcpio`` is convenient::

  curl -L https://github.com/ahesford/mkinitcpio-rclocal/archive/master.tar.gz | tar -zxvf - -C /tmp
  mkdir -p /etc/zfsbootmenu/initcpio/{install,hooks}
  cp /tmp/mkinitcpio-rclocal-master/rclocal_hook /etc/zfsbootmenu/initcpio/hooks/rclocal
  cp /tmp/mkinitcpio-rclocal-master/rclocal_install /etc/zfsbootmenu/initcpio/install/rclocal
  rm -r /tmp/mkinitcpio-rclocal-master

Next, create an ``rc.local`` script that can be run within the mkinitcpio image to configure the ``eth0`` interface::

  cat > /etc/zfsbootmenu/initcpio/rc.local <<RCEOF
  #!/bin/sh

  # Don't attempt to configure an interface that does not exist
  ip link show dev eth0 >/dev/null 2>&1 || exit

  # Bring up the interface
  ip link set dev eth0 up

  # Configure a static address for this host
  ip addr add 192.168.1.2/24 brd + dev eth0
  ip route add default via 192.168.1.1

  # Add some name servers
  cat > /etc/resolv.conf <<-EOF
    nameserver 1.1.1.1
    nameserver 8.8.8.8
    EOF
  RCEOF

.. note::

  If your Ethernet interface is called something other than ``eth0`` or your static IP configuration is different,
  adjust the script as needed.

To ensure that the ``rclocal`` module is installed and run in the ZBM image, either append ``rclocal`` to the array
defined on the ``HOOKS`` line in ``/etc/zfsbootmenu/mkinitcpio.conf`` or run

.. code-block::

  sed -e '/HOOKS=/a HOOKS+=(rclocal)' -i /etc/zfsbootmenu/mkinitcpio.conf

The ``rclocal`` module should be told where it can find the ``rc.local`` script to install and run by running::

  echo 'rclocal_hook=/etc/zfsbootmenu/initcpio/rc.local' >> /etc/zfsbootmenu/mkinitcpio.conf

Finally, make sure to include the ``ip`` executable in your initramfs image by manually adding ``ip`` to the
``BINARIES`` array in ``/etc/zfsbootmenu/mkinitcpio.conf`` or by running

.. code-block::

  sed -e '/BINARIES=/a BINARIES+=(ip)' -i /etc/zfsbootmenu/mkinitcpio.conf

Dropbear
~~~~~~~~

Arch Linux provides a `mkinitcpio-dropbear <https://archlinux.org/packages/community/any/mkinitcpio-dropbear/>`_ package
that provides a straightforward method for installing, configuring and running the dropbear SSH server inside a
mkinitcpio image. This package is based on a
`project of the same name <https://github.com/grazzolini/mkinitcpio-dropbear>`_ by an Arch Linux developer. A
`fork of the mkinitcpio-dropbear project <https://github.com/ahesford/mkinitcpio-dropbear>`_ contains a few minor
improvements in runtime configuration and key management. If these improvements are not needed, using the upstream
project is perfectly acceptable.

Once again, the mkinitcpio module must first be downloaded and installed::

  curl -L https://github.com/ahesford/mkinitcpio-dropbear/archive/master.tar.gz | tar -zxvf - -C /tmp
  mkdir -p /etc/zfsbootmenu/initcpio/{install,hooks}
  cp /tmp/mkinitcpio-dropbear-master/rclocal_hook /etc/zfsbootmenu/initcpio/hooks/dropbear
  cp /tmp/mkinitcpio-dropbear-master/rclocal_install /etc/zfsbootmenu/initcpio/install/dropbear
  rm -r /tmp/mkinitcpio-dropbear-master

The upstream ``dropbear`` module will attempt to copy host OpenSSH keys into ``/etc/dropbear`` if possible; otherwise,
it will generate random host keys. Both options are undesirable. Copying host keys will leave these protected files
directly accessible to anybody able to read a ZFSBootMenu image, which is probably every user on the system. Generating
unique keys with each run inhibits your ability to detect interlopers when you connect to your bootloader via SSH. My
fork will, by default, respect any existing dropbear keys available as ``/etc/dropbear/dropbear_*_host_key``. Therefore,
make some new host keys for use in your ZFSBootMenu image::

  mkdir -p /etc/dropbear
  for keytype in rsa ecdsa ed25519; do
      dropbearkey -t "${keytype}" -f "/etc/dropbear/dropbear_${keytype}_host_key"
  done

The module also requires, at ``/etc/dropbear/root_key``, a set of authorized SSH keys that will be given access to the
``root`` account in the image. On a single-user system, it is sufficient to do::

  ln -s ${HOME}/.ssh/authorized_keys /etc/dropbear/root_key

assuming that ``${HOME}`` points to the home directory of the user who should be given access to ZFSBootMenu.

Finally, enable the ``dropbear`` module in ``/etc/zfsbootmenu/mkinitcpio.conf`` by manually appending ``dropbear`` to
the ``HOOKS`` array, or by running::

  sed -e '/HOOKS.*rclocal/a HOOKS+=(dropbear)' -i /etc/zfsbootmenu/mkinitcpio.conf

Final Steps
~~~~~~~~~~~

With the above configuration complete, running ``generate-zbm`` should produce a ZFSBootMenu image that contains the
necessary components to enable an SSH server in your bootloader. This can be verified with the ``lsinitrd`` tool
provided by dracut or the ``lsinitcpio`` tool provided by mkinitcpio. (The ``lsinitcpio`` tool is not able to inspect
UEFI bundles, but ``lsinitrd`` can.) In the file listing, you should see keys in ``/etc/dropbear``, the ``dropbear`` and
``ip`` executables, and the file ``root/.ssh/authorized_keys``.

After rebooting, ZFSBootMenu should configure the network interface, launch an SSH server and accept connections on TCP
port 22 by default. If your SSH client complains because it finds ZFSBootMenu keys when it expects to find your normal
host keys, you may wish to reconfigure dropbear to listen on a non-standard port. My fork of ``mkinitcpio-dropbear``
supports this by writing a ``dropbear_listen`` definition to ``/etc/dropbear/dropbear.conf``::

  echo 'dropbear_listen=2222' > /etc/dropbear/dropbear.conf

After writing this file (adjust ``2222`` to whatever port you prefer), re-run ``generate-zbm``, reboot and confirm that
dropbear listens where expected.

Accessing ZFSBootMenu Remotely
------------------------------

When you connect to ZFSBootMenu via SSH, you will be presented a simple shell prompt. Launch ``zfsbootmenu`` to start
the menu interface over the remote connection::

  zfsbootmenu

You may then use the menu as if you were connected locally.

.. note::

  recent versions of ZFSBootMenu automatically set the ``TERM`` environment variable to ``linux``. If you are running an
  older version, your SSH client may have provided a more specific terminal definition that will not be recognized by
  the restricted environment provided by ZFSBootMenu. Under these circumstances, you may need to run::

    export TERM=linux

  from the login shell to ensure that basic terminal functionality works as expected.

If you followed the :doc:`Void Linux ZFSBootMenu install guide </guides/void-linux/single-disk-uefi>` and configured
rEFInd to launch ZFSBootMenu, you may need to remove the ``zbm.skip`` argument from the default menu entry if you would
like remote access and you have no encrypted boot environments. Otherwise, rEFInd will attempt to bypass the ZFSBootMenu
countdown and your default boot environment will be started immediately if possible. In this case, either set
``zbm.timeout`` to a suitably long delay (*e.g.*, 60 sec) to give yourself time to connect and launch ZFSBootMenu
remotely before the automatic boot can proceed, or use ``zbm.show`` by default to prevent automatic boot and force the
local instance to show the interactive menu immediately.

.. note::

  To provide some safety against multi-user conflicts, only one ZFSBootMenu instance is allowed to run at any given
  time. If you have encrypted boot environments, this will generally not present an issue, because the local instance
  will always block awaiting passphrase entry before launching the menu instance. Otherwise, the later instance of
  ZFSBootMenu will wait patiently for the earlier instance to terminate before continuing. If you are *certain* that the
  currently running instance is not being actively used, you can interrupt the wait loop by pressing ``[ESC]`` and then
  run::

    rm /zfsbootmenu/active

  to eliminate the indicator of the other running instance. You may then run ``zfsbootmenu`` again to launch the menu.

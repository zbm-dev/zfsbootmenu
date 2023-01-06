Configure Live Environment
--------------------------

Disable automounting
~~~~~~~~~~~~~~~~~~~~

.. code-block::

	gsettings set org.gnome.desktop.media-handling automount false

Switch to a root account
~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  sudo -i

.. include:: ../_include/os-release.rst

Enable filesystems repository
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

	zypper -n addrepo https://download.opensuse.org/repositories/filesystems/$(lsb_release -rs)/filesystems.repo
	zypper refresh 

Install updated ZFS packages
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

	zypper -n install zfs zfs-kmp-default
	modprobe zfs	

.. include:: ../_include/zgenhostid.rst

..
 vim: softtabstop=2 shiftwidth=2 textwidth=120

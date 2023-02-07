Configure Live Environment
--------------------------

.. include:: ../_include/os-release.rst

Add package repositories
~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

	cat <<EOF > /etc/apk/repositories
	http://dl-cdn.alpinelinux.org/alpine/latest-stable/main/
	https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/
	EOF
	apk update

Setup additional tools 
~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  apk add zfs sgdisk wipefs eudev
  modprobe zfs
  setup-devd udev

.. include:: ../_include/zgenhostid.rst

..
  vim: softtabstop=2 shiftwidth=2 textwidth=120

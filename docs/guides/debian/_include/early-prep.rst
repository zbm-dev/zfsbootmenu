Early Setup
-----------

Switch to a root shell
~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  sudo su --login

Configure and update APT
~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  cat <<EOF > /etc/apt/sources.list
  deb http://deb.debian.org/debian bullseye main contrib
  deb-src http://deb.debian.org/debian bullseye main contrib
  EOF
  apt update

.. note::

  You may see faster downloads replacing ``deb.debian.org`` with a local mirror. If you want to use HTTPS transport, make
  sure that the ``ca-certificates`` and ``apt-transport-https`` packages are installed and your mirror has a valid
  certificate; otherwise, apt will refuse to use the mirror.

Install helpers
~~~~~~~~~~~~~~~

.. code-block::

  apt install debootstrap gdisk dkms linux-headers-$(uname -r)
  apt install zfsutils-linux

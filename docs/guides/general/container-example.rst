A Simple Host-Specific Container Build
======================================

``zbm-builder.sh`` mounts a build directory (by default, the current working directory) into the container to provide a
path to inject custom configuration into the container. If the system will manage ZFSBootMenu images exclusively via a
build container, an obvious location for the build directory is ``/etc/zfsbootmenu``. Start by creating this directory
and populating a simple ``config.yaml`` for container builds::

  mkdir -p /etc/zfsbootmenu

  cat > /etc/zfsbootmenu/config.yaml <<EOF
  Global:
    InitCPIO: true
  Components:
    Enabled: false
  EFI:
    Enabled: true
    Versions: false
  Kernel:
    Prefix: zfsbootmenu
    CommandLine: zfsbootmenu ro quiet loglevel=4 nomodeset
  EOF

  curl -L -O /etc/zfsbootmenu/zbm-builder.sh https://raw.githubusercontent.com/zbm-dev/zfsbootmenu/master/zbm-builder.sh
  chmod 755 /etc/zfsbootmenu/zbm-builder.sh

In this configuration, ``mkinitcpio`` will be used instead of ``dracut``. Component generation is disabled, so
``generate-zbm`` will produce only a UEFI bundle. That bundle has numeric versioning disabled, so ``generate-zbm`` will
produce an unversioned ``zfsbootmenu.EFI``; if the generator detects an existing ``zfsbootmenu.EFI`` in the output
directory, it will make a single backup of that file as ``zfsbootmenu-backup.EFI`` before overwriting it. A simple
kernel command-line is specified and may be overridden as necessary.

For some systems, it is necessary to tear down USB devices before ZFSBootMenu launches a boot environment. Even when
this is not needed, it is generally harmless. The ZFSBootMenu repository offers a
:zbm:`teardown hook <contrib/xhci-teardown.sh>` for this purpose, and it is possible to instruct ``mkinitcpio`` to
include this teardown hook straight from the version of ZFSBootMenu inside the container::

  mkdir -p /etc/zfsbootmenu/mkinitcpio.conf.d
  echo "zfsbootmenu_teardown=( /zbm/contrib/xhci-teardown.sh )" \
      > /etc/zfsbootmenu/mkinitcpio.conf.d/teardown.conf

The default ``mkinitcpio.conf`` in the container, which should generally not be overridden, will source all files in
``/etc/zfsbootmenu/mkinitcpio.conf.d``.

Custom Font
-----------

On high-resolution screens, the Linux kernel does not always do a good job choosing a console font. A nice font can be
explicitly specified in the ZFSBootMenu configuration for ``mkinitcpio``. The container entrypoint must be told to
install the desired font and the ``mkinitcpio`` configuration should include the necessary module and executable to set
the font::

  echo "BUILD_ARGS+=( -p terminus-font )" >> /etc/zfsbootmenu/zbm-builder.conf

  cat > /etc/zfsbootmenu/mkinitcpio.conf.d/consolefont.conf <<EOF
  BINARIES+=(setfont)
  HOOKS+=(consolefont)
  EOF

This approach uses the configuration file capability of ``zbm-builder.sh`` to specify build options without requiring
that they be included on the command line.

As configured, ``mkinitcpio`` will not see a configured console font and will omit the font from generated images. To
make ``mkinitcpio`` aware of the desired font, it must be specified in ``/etc/rc.conf`` within the container. The
"terraform" capabilities of the container entrypoint can be used to accomplish this::

  mkdir -p /etc/zfsbootmenu/rc.d

  cat > /etc/zfsbootmenu/rc.d/consolefont <<EOF
  #!/bin/sh
  sed -e '/FONT=/a FONT="ter-132n"' -i /etc/rc.conf
  EOF

  chmod 755 /etc/zfsbootmenu/rc.d/consolefont

When the container entrypoint finds an ``rc.d`` subdirectory in the build root, it will run each executable file therein
before generating a ZFSBootMenu image.  If any of these executable should fail, image generation is aborted.

Host-Specific Files
-------------------

By default, ``zbm-builder.sh`` will copy the file ``/etc/hostid`` from the host to the build directory so that the
hostid of the generated ZFSBootMenu image will match that of your host. This is often desirable for customized builds,
but it would be undesirable for copies of these files in ``/etc/zfsbootmenu`` to fall out of synchronization with the
host versions. To avoid this issue, tell ``zbm-builder.sh`` to remove any copies in ``/etc/zfsbootmenu`` before
determining whether the host versions should be copied in for image creation::

  echo "REMOVE_HOST_FILES=yes" >> /etc/zfsbootmenu/zbm-builder.conf

If you would rather not see those files at all, it is possible to instruct ``generate-zbm`` to remove them after they
are used. Edit the configuration at ``/etc/zfsbootmenu/config.yaml`` and add the following key:

.. code-block:: yaml

  Global:
    PostHooksDir: /build/cleanup.d

Alternatively, tell the build container to add this option dynamically::

  echo "BUILD_ARGS+=( -e '.Global.PostHooksDir=\"/build/cleanup.d\"' )" \
      >> /etc/zfsbootmenu/zbm-builder.conf

Next, create a post-generation hook to remove the files::

  mkdir -p /etc/zfsbootmenu/cleanup.d

  cat > /etc/zfsbootmenu/cleanup.d/hostfiles <<EOF
  #!/bin/sh
  rm -f /build/zpool.cache /build/hostid
  EOF

  chmod 755 /etc/zfsbootmenu/cleanup.d/hostfiles

The Output Directory
--------------------

At this point, it should be possible to generate images by running

.. code-block::

  cd /etc/zfsbootmenu && ./zbm-builder.sh

However, these images will reside in ``/etc/zfsbootmenu/build`` and will require manual management. A better alternative
is to let ``generate-zbm`` manage the ZFSBootMenu output directory directly. Assuming that ZFSBootMenu images should be
installed in ``/boot/efi/EFI/zfsbootmenu``, tell ``zbm-builder.sh`` to mount the directory inside the container, and
tell the container that it should write its images to the mounted directory::

  cat >> /etc/zfsbootmenu/zbm-builder.conf <<EOF
  RUNTIME_ARGS+=( -v /boot/efi/EFI/zfsbootmenu:/output )
  BUILD_ARGS+=( -o /output )
  EOF

Now, running

.. code-block::

  cd /etc/zfsbootmenu && ./zbm-builder.sh

should create images directly in ``/boot/efi/EFI/zfsbootmenu`` and create a backup of any existing ``zfsbootmenu.EFI``.

Networking in Rootfull Containers
---------------------------------

Manipulating files in ``/etc/zfsbootmenu`` and ``/boot/efi/EFI/zfsbootmenu`` may require root privileges, which means
that ``zbm-builder.sh`` and the build container will need to run as root. In some configurations, ``podman`` may not
provide working networking for rootfull containers by default. A simple fix is to allow the containers to use the host
network stack, which can be accomplished by running

.. code-block::

  echo "RUTNIME_ARGS+=( --net=host )" >> /etc/zfsbootmenu/zbm-builder.conf

Adding Remote Access Capabilities
---------------------------------

The process for including ``dropbear`` for remote access to container-built
ZFSBootMenu images is largely the same as the
:doc:`process for host-built images </guides/general/remote-access>`, but care must be taken to ensure that all
necessary components are available within the build directory.

- The :doc:`core configuration changes <mkinitcpio>` should be **ignored**. They are unnecessary with the
  container configuration described above.

- The :ref:`basic network access <remote-mkinitcpio-net>` and :ref:`dropbear <remote-mkinitcpio-dropbear>` instructions
  are generally applicable, except **no changes should be made to** ``/etc/zfsbootmenu/mkinitcpio.conf`` and **all
  references to paths in** ``/etc/dropbear`` **should be replaced with corresponding references to paths in**
  ``/etc/zfsbootmenu/dropbear``.

Specific alterations are noted below.

Configuring Basic Network Access
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Commands to fetch and unpack the ``mkinitcpio-rclocal`` module and create an ``/etc/zfsbootmenu/initcpio/rc.local``
script still apply as described to containerized builds. Subsequent ``sed`` and ``echo`` commands that write to
``/etc/zfsbootmenu/mkinitcpio.conf`` should be ignored because this file should not exist. Instead, create a
configuration snippet that will add network configuration to the ZFSBootMenu image::

  cat > /etc/zfsbootmenu/mkinitcpio.conf.d/network.conf <<EOF
  BINARIES+=(ip dhclient dhclient-script)
  HOOKS+=(rclocal)
  rclocal_hook="/build/initcpio/rc.local"
  EOF

.. note::

  If a static IP address will be configured, it is acceptable to leave ``dhclient`` and ``dhclient-script`` out of the
  ``BINARIES`` array.

Next, edit ``/etc/zfsbootmenu/config.yaml`` to add a hook directory configuration telling `mkinitcpio` where to find
custom modules:

.. code-block:: yaml

  General:
    InitCPIOHookDirs:
      - /build/initcpio
      - /usr/lib/initcpio

Configuring Dropbear
~~~~~~~~~~~~~~~~~~~~

The commands to fetch and unpack the ``mkinitcpio-dropbear`` module still apply to containerized builds. Instead of
adding ``dropbear`` to the non-existent configuration ``/etc/zfsbootmenu/mkinitcpio.conf``, create a snippet::

  cat > /etc/zfsbootmenu/mkinitcpio.conf.d/dropbear.conf <<EOF
  HOOKS+=(dropbear)
  EOF

Rather than creating keys (and optional configuration) in ``/etc/dropbear``, create the keys and configuration in
``/etc/zfsbootmenu/dropbear``::

  mkdir -p /etc/zfsbootmenu/dropbear

  ## Not strictly required; see note below
  for keytype in rsa ecdsa ed25519; do
      dropbearkey -t "${keytype}" -f "/etc/dropbear/dropbear_${keytype}_host_key"
  done

  ## If desired
  echo 'dropbear_listen=2222' > /etc/zfsbootmenu/dropbear/dropbear.conf

.. note::

  Generating keys is not strictly necessary and can be skipped if ``dropbearkey`` is not available on the host. The
  build container will generally lack SSH host keys, so the ``mkinitcpio-dropbear`` module will default to creating new,
  random keys in the build directory. These keys will persist for subsequent use.

The file ``/etc/zfsbootmenu/dropbear/root_key`` is required to provide a list of authorized keys in the ZFSBootMenu
image. Unlike with host builds, this may not be a symlink to a user's ``authorized_keys`` file because that path will be
unavailble in the container. Instead, simply copy a desired ``authorized_keys`` file to
``/etc/zfsbootmenu/dropbear/root_key``. Alternatively, dynamism can be preserved by relying on bind-mounting a specific
``authorized_keys`` file into the build container::

  echo "RUNTIME_ARGS+=( -v /home/${dropbear_user}/.ssh/authorized_keys:/authorized_keys:ro ) >> /etc/zfsbootmenu/zbm-builder.conf
  ln -s /authorized_keys /etc/zfsbootmenu/dropbear/root_key

Replace ``${dropbear_user}`` with the desired user whose ``authorized_keys`` file should govern access to ZFSBootMenu.

Make sure that the build container installs the packages necessary to provide ``dropbear``::

  echo "BUILD_ARGS+=( -p dropbear -p psmisc )" >> /etc/zfsbootmenu/zbm-builder.conf

Finally, add a "terraform" script to link the expected ``/etc/dropbear`` directory to that in the build directory::

  cat > /etc/zfsbootmenu/rc.d/dropbear <<EOF
  #!/bin/sh

  [ -d /build/dropbear ] || exit 0

  if [ -d /etc/dropbear ] && [ ! -L /etc/dropbear ]; then
      if ! rmdir /etc/dropbear; then
          echo "ERROR: failed to remove existing /etc/dropbear directory"
          exit 1
      fi
  fi

  if ! ln -Tsf /build/dropbear /etc/dropbear; then
      echo "ERROR: failed to make /etc/dropbear symlink"
      exit 1
  fi
  EOF

  chmod 755 /etc/zfsbootmenu/rc.d/dropbear

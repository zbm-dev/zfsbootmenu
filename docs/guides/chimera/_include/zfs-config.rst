ZFS Configuration
-----------------

Install ZFS and kernel
~~~~~~~~~~~~~~~~~~~~~~

.. code-block::

  apk add --no-interactive linux-lts-zfs-bin

Configure initramfs-tools
~~~~~~~~~~~~~~~~~~~~~~~~~

.. tabs::

  .. group-tab:: Unencrypted

    .. code-block::

      No required steps

  .. group-tab:: Encrypted

    .. code-block::

      cat << 'EOF' > /usr/share/initramfs-tools/hooks/zfsencryption
      if [ "$1" = "prereqs" ]; then
        exit 0
      fi

      . /usr/share/initramfs-tools/hook-functions

      [ -d "${DESTDIR}/etc/zfs" ] || mkdir "${DESTDIR}/etc/zfs"

      for keyfile in /etc/zfs/*.key; do
        [ -e "${keyfile}" ] || continue
        cp "${keyfile}" "${DESTDIR}/etc/zfs/"
      done
      EOF

      chmod +x /usr/share/initramfs-tools/hooks/zfsencryption
      echo "UMASK=0077" > /etc/initramfs-tools/conf.d/umask.conf
  
      update-initramfs -c -k all

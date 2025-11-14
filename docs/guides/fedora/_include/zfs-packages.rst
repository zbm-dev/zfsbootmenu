Remove the ``zfs-fuse`` package to avoid conflicts with OpenZFS packages.

.. code-block::

  rpm -e --nodeps zfs-fuse

Disable the ``updates`` repository to ensure that the correct kernel headers are installable.

.. code-block::

  dnf config-manager --disable updates

Install kernel headers and the OpenZFS package.

.. code-block::

  dnf --releasever=${VERSION_ID} install -y \
    https://zfsonlinux.org/fedora/zfs-release-2-5$(rpm --eval "%{dist}").noarch.rpm

  dnf install -y https://dl.fedoraproject.org/pub/fedora/linux/releases/${VERSION_ID}/Everything/x86_64/os/Packages/k/kernel-devel-$(uname -r).rpm

  dnf install -y zfs 


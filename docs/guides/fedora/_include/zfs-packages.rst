Remove the ``zfs-fuse`` package to avoid conflicts with OpenZFS packages.

.. code-block::

  rpm -e --nodeps zfs-fuse

Disable the ``updates`` repository to ensure that the correct kernel headers are installable.

.. code-block::

  dnf config-manager setopt updates.enabled=0

Install kernel headers and the OpenZFS package.

.. note::

  Refer to the `list of available zfs-release RPMs <https://github.com/zfsonlinux/zfsonlinux.github.com/tree/master/fedora>`_.

.. code-block::

  dnf --releasever=${VERSION_ID} install -y \
    https://zfsonlinux.org/fedora/zfs-release-3-0$(rpm --eval "%{dist}").noarch.rpm

  dnf install -y https://dl.fedoraproject.org/pub/fedora/linux/releases/${VERSION_ID}/Everything/x86_64/os/Packages/k/kernel-devel-$(uname -r).rpm

  dnf install -y zfs 


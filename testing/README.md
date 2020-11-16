# Requirements

The testing environment setup and runtime depends on the following tools:

* kpartx
* qemu
* yq-go
* ZFS
* kvm kernel module

# Creating a ZFSBootMenu Test Pool for QEMU

First, run `./setup.sh -a`; this will create, if necessary, a test directory
(chosen automatically or specified with the `-D` command-line flag) and, within
the test directory:

* Create a test pool
  1. Create a 2GB RAW image file,
  2. Attach it to a loopback device,
  3. Create a GPT label and a ZFS pool `ztest`,
  4. Install Void base-minimal onto the pool,
  5. Configure the installation, and
  6. Set the `bootfs` property of `ztest`.
* Create a local generate-zbm configuration file (`local.yaml`)
* Create a local dracut.conf.d configuration directory (`dracut.conf.d`) with a
  default configuration file
* Create a local dracut modules directory (`modules.d`) with symlinks to all of
  the system modules, and a symlink to the `90zfsbootmenu` directory in the
  current git checkout.

These options can be individually executed if you need to reset any single
portion of your testing environment.

The root password in the test installation will be set to `zfsbootmenu`.

# Booting the Test Pool

To boot the test environment, invoke `./run.sh`. This may be done as a regular
user, but make sure your user is a member of the `kvm` group if you wish to
leverate `KVM`.

The following defaults can be set to a local default in the `.config`:

```
DRIVE="format=raw,file=zfsbootmenu-pool.img"
INITRD="initramfs-bootmenu.img"
MEMORY="2048M"
SMP="2"
DISPLAY="gtk"
APPEND="loglevel=7 timeout=5 root=zfsbootmenu:POOL=ztest"
```

The ZFSBootMenu kernel command line (specified in the `APPEND` variable) can be
overridden per run by passing an optional `-a` argument to `./run.sh`. The `-n`
argument can be used to skip image regeneration, allowing you to boot the
existing initramfs.

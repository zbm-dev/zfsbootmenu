# Creating a ZFSBootMenu Test Pool for QEMU

First, run (as root) `./setup.sh` to:
1. Create a 1GB RAW image file,
2. Attach it to the `loop0` loopback device,
3. Create a GPT label and a ZFS pool `ztest`,
4. Install Void base-minimal onto the pool,
5. Configure the installation, and
6. Set the `bootfs` property of `ztest`.

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
APPEND="loglevel=7 timeout=5 zfsbotmenu:POOL=ztest"
```

The ZFSBootMenu kernel command line (specified in the `APPEND` variable) can be
overridden per run by passing an optional `-a` argument to `./run.sh`.

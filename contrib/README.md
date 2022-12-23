# User-Contributed Scripts for ZFSBootMenu

The `contrib` directory contains an assorted collection of helper scripts that
augment core functionality. These scripts are reviewed and approved by members
of the core team, but not all are thoroughly tested. Some have not been tested
at all. User-contributed scripts are intended as starting points for customized
[setup hooks](../docs/man/zfsbootmenu.7.rst) that can be deployed within the
ZFSBootMenu environment or for [`generate-zbm`
hooks](../docs/man/generate-zbm.5.rst) that alter the process of creating
ZFSBootMenu images.

## Script Directory

Brief descriptions of contributed scripts appear below for convenience. Please
review the scripts themselves for more thorough descriptions of their use.

- `console-init.sh` - In some configurations, the dracut event loop that
  configures the ZFSBootMenu environment will fail to initialize the console
  with desired font and keymap settings. This script can be added as an "early
  setup" hook to force console initialization.

- `esp-sync.sh` - This script can run as a "post-image" hook to `generate-zbm`
  to synchronize the contents of one EFI system partition with others, providing
  tolerance against disk failures.

- `keycache.sh` - This early-setup hook provided a simple means for run-time
  caching of ZFS encryption keys. Although the script has been retained for
  historical reference, use of the `org.zfsbootmenu:keysource` property is now
  the preferred method to control caching of filesystem credentials.

- `luks-unlock.sh` - This is a proof of concept for storing ZFS
  native-encryption keys on a LUKS-encrypted volume. When installed as an
  early-setup hook, this facilitates, *e.g.*, multiple-slot keys for ZFS pools
  that use native encryption.

- `remote-ssh-build.sh` - This is a standalone script intended to wrap the
  `zbm-builder.sh` image-builder script, incorporating a dropbear SSH server,
  host keys and an `authorized_keys` file that permit remote access and pool
  unlocking within a ZFSBootMenu image.

- `snapshot-teardown.sh` - This "teardown" hook will capture a pre-boot
  snapshot of the boot environment that has been selected for booting.

- `syslinux-update.sh` - This script can run as a post-image hook for
  `generate-zbm` to construct a configuration file for syslinux. This provides
  an extension to basic functionality that was originally built into
  `generate-zbm` itself.

- `xhci-teardown.sh` - ZFSBootMenu relies on `kexec` to launch kernels
  within boot environments. Some hardware, including certain XHCI USB
  controllers, cannot be properly re-initialized after `kexec` jumps into the
  new kernel. This teardown hook unbinds all detected XHCI controllers from the
  ZFSBootMenu kernel before jumping into the new kernel, allowing devices to be
  properly initialized.

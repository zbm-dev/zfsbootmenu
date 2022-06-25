# Remote SSH Build

The script `contrib/remote-ssh-build.bash` is heavily based on
[Remote-Access-to-ZBM](https://github.com/zbm-dev/zfsbootmenu/wiki/Remote-Access-to-ZBM)


## Building ZBM

Running the script will create custom SSH host keys, copy the `authorized_keys`
file from the current user, and set up config files with reasonable defaults.
These are stored in `ssh-data`, and can be customized. In particular, adapting
`authorized_keys` might be desirable.

All files will end up unencrypted in the final initrd, so it is good to use
host keys distinct from the true OS.


## Filesystem

The root filesystem needs to be unlockable by the primary initrd (the one that
is started by ZBM). This can be done by using a key file stored in that initrd.
(Instructions below for ubuntu, but can be adapted to various platforms.)

This key file will be stored unencrypted in the initramfs, so make sure access
to it is protected.

```
mkdir -p -m 700 /etc/zfs/keys
cp passwordfile /etc/zfs/keys/rpool.key
zfs change-key \
    -o keylocation=file:///etc/zfs/keys/rpool.key \
    -o keyformat=passphrase rpool
update-initramfs -u
chmod go= /boot
```


## Usage

To unlock the pool remotely, log in via ssh, then start zfsbootmenu, enter the
key and continue as usual.

```
ssh root@host -p 222
zfsbootmenu
```

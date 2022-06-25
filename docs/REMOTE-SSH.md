# Remote SSH Support

There are several ways to do this, below is only one possible option (which has
worked at least once in the past). The script changes are heavily based on the
instructions in the [Remote-Access-to-ZBM](https://github.com/zbm-dev/zfsbootmenu/wiki/Remote-Access-to-ZBM)


## Preparation

The ZBM initrd will contain its own SSH host keys, which will be created by
`zbm-builder.sh` if they are not already present in `etc/dropbear` as
`ssh_host_ecdsa_key` and `ssh_host_rsa_key`.
Authentication of clients happens via `etc/dropbear/authorized_keys`. All
files will end up unencrypted in the final initrd, so it is good to use
host keys distinct from the true OS.


## ZBM

The scripts on this branch have been updated to install dropbear ssh server in
the ZBM initrd. Make sure you have the required prerequisites mentioned in
[BUILD.md](BUILD.md). Then a custom image can easily be built by running the
following (possibly as root, depending on permissions required by your setup)

```
./releng/docker/image-build.sh zbm-build
buildah push localhost/zbm-build docker-daemon:localhost/zbm-build:latest
./zbm-builder.sh -H -C -i localhost/zbm-build -l . -s
```


## Filesystem

The root filesystem needs to be unlockable by the primary initrd (the one that
is started by ZBM). This can be done by using a key file stored in that initrd.
(Instructions below for ubuntu, but can be adapted to various platforms.)

```
mkdir -p -m 700 /etc/zfs/keys
cp passwordfile /etc/zfs/keys/rpool.key
zfs change-key \
    -o keylocation=file:///etc/zfs/keys/rpool.key \
    -o keyformat=passphrase rpool
update-initramfs -u
```


## Usage

To unlock the pool remotely, log in via ssh, then start zfsbootmenu, enter the key
and continue as usual.

```
ssh root@host -p 222
zfsbootmenu
```

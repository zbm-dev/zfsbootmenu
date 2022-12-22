Complete beginner's guide to installing Debian with ZFSBootMenu
===============================================================

.. note::

  This guide is still a work in progress and has not received thorough review from the official ZFSBootMenu team.

.. contents:: Contents
  :depth: 2
  :local:
  :backlinks: none

This is a beginner's guide to installing ZFSBootMenu onto an EFI-boot capable computer, and setting up a basic Linux
install to go with it. It assumes basic knowledge of the Linux command line including editing text files with ``vim``,
``nano``, or ``emacs``, as well as a working knowledge of ZFS concepts. If you need a primer or refresher on ZFS before
following this guide, `this article
<https://arstechnica.com/information-technology/2020/05/zfs-101-understanding-zfs-storage-and-performance/>`_
should suffice.

This guide is based on sections of several pre-existing guides, which you might find it helpful to consult if you
encounter any difficulties following this guide with your particular distribution and hardware:

1. `OpenZFS: Debian root-on-ZFS guide
   <https://openzfs.github.io/openzfs-docs/Getting%20Started/Debian/Debian%20Bullseye%20Root%20on%20ZFS.html>`_
2. :doc:`/guides/general/uefi-booting`
3. :doc:`/guides/debian/uefi-install`

What is ZFSBootMenu?
--------------------

ZFSBootMenu is a *boot manager* for Linux - just like GRUB, only better. A boot manager is the first software that runs
when you start your computer, and it's responsible for finding your Linux installation and starting it. 

ZFSBootMenu is designed to start Linux installations that have been installed directly on to ZFS, and has a number of
advantages over GRUB, for example:

* It can allow you to boot a previous "snapshot" of your Linux installation if something has gone wrong during one of
  your regular system updates.
* It provides a full linux system recovery shell with ZFS installed, making it easy to do recovery of a system with a
  damaged ZFS pool.
* It's much simpler to install than GRUB when building a Root-on-ZFS Linux system.

Great! How can I use it on my machine?
--------------------------------------

Assuming that your machine supports EFI booting (and most machines made after 2011 do), then there are three things that
you need to use ZFSBootMenu:

1. An EFI system partition with ZFSBootMenu on it, and that has been registered with your EFI firmware.
2. A pool with a filesystem on it to hold your Linux installation.
3. A Linux installation, located on the filesystem.

If you have those three things, then on startup your computer's EFI firmware will launch ZFSBootMenu. ZFSBootMenu will
then scan your disks looking for pools and for datasets that have Linux installations on them, and will present you with
a menu so you can choose which one to start. ZFSBootMenu also gives you a menu of options for inspecting the various
pools and Linux installations on your computer, and you can even enter a full Linux shell with ZFS installed to make any
changes or repairs that you need to before booting.

The steps for setting up those three things on your computer will depend on where you are starting from. You might want
to do a clean install, wiping your disk(s) and starting from scratch, or you might have an existing Root-on-ZFS
installation using GRUB that you want to convert to ZFSBootMenu. We'll cover these two scenarios in the sections below,
and hopefully if you have a different scenario you will be able to figure out what you need to do from these examples as
well.

The exact commands shown in this document are for installing Debian 11, however it should be easy to figure out what the
equivalent commands are for other Linux distributions by also referring to other guides on the
`OpenZFS wiki <https://openzfs.github.io/openzfs-docs/Getting%20Started/index.html>`_ or the
:doc:`ZFSBootMenu documentation </index>`.

How do I know if my computer supports EFI booting?
--------------------------------------------------

The easiest way to check if your computer supports EFI booting is by looking in your BIOS/firmware system settings when
your computer first starts and before it has booted. You do this by pressing a key as soon as your computer starts -
often the screen will have a startup message telling you what key to press, but sometimes it just displays a logo and
you will need to do a web search to find out which key it is - often it's the ``[delete]`` key on Dell or Asus machines,
the ``[Enter]`` and then ``[F1]`` key on Lenovo, or the ``[F10]`` on HP, and so on.

Different computers have different system setting menus, so you will have to figure out where the boot settings are and
then look for "EFI boot" options, and confirm they are enabled. If there are no EFI settings at all and you have a very
old machine, then your computer may not support EFI boot and you will have to consult a different guide on how to set up
MBR boot with ZFSBootMenu instead. You can also do a web search for your computer's user manual if you are unsure about
the BIOS setting menus or whether EFI boot is supported.

Installation environment
------------------------

In order to set up ZFSBootMenu you need a Linux command line with ZFS installed. If you already have a Root-on-ZFS
environment with an EFI partition and you just want to replace GRUB with ZFSBootMenu, then you can just use a root shell
on your existing system, and you can skip ahead to :ref:`copy-zbm-to-efi` below. If however you want to do a clean
install of a Root-on-ZFS Linux system with ZFSBootMenu, then you will need to boot your computer using a *live USB
drive* so that you don't boot off any of the disks in your machine and are therefore free to erase and configure them
without interfering with the Linux command line you are using.

Creating a live USB image
~~~~~~~~~~~~~~~~~~~~~~~~~

To create a live USB image, see the instructions on your distribution's website. For this example we are using Debian
11, so we would follow `the instructions for fetching a Debian image <https://www.debian.org/CD/live/>`_, which involves
downloading the live USB image via bittorrent.

Once you have a live USB image for your distribution of choice, you can write it to a USB drive. First, you need to
identify the device node for your USB drive. Connect it to your machine, and then look in the ``/dev/disk/by-id``
directory::

  ls -l /dev/disk/by-id

This will display various id-based aliases for the disks on your system. Find the one that looks like it's your USB
drive, and note the ``sd*`` name that it points to::

  lrwxrwxrwx 1 root root  9 Jul  5 17:03 ata-Samsung_SSD_870_EVO_1TB_S5Y2NF0R12***** -> ../../sda
  lrwxrwxrwx 1 root root 10 Jul  5 17:03 ata-Samsung_SSD_870_EVO_1TB_S5Y2NF0R12*****-part1 -> ../../sda1
  lrwxrwxrwx 1 root root 10 Jul  5 17:03 ata-Samsung_SSD_870_EVO_1TB_S5Y2NF0R12*****-part2 -> ../../sda2
  lrwxrwxrwx 1 root root 10 Jul  5 17:03 ata-Samsung_SSD_870_EVO_1TB_S5Y2NF0R12*****-part3 -> ../../sda3
  lrwxrwxrwx 1 root root 10 Jul  5 17:03 ata-Samsung_SSD_870_EVO_1TB_S5Y2NF0R12*****-part4 -> ../../sda4
  lrwxrwxrwx 1 root root 10 Jul  5 17:03 ata-Samsung_SSD_870_EVO_1TB_S5Y2NF0R12*****-part5 -> ../../sda5
  lrwxrwxrwx 1 root root 10 Jul  5 17:03 ata-Samsung_SSD_870_EVO_1TB_S5Y2NF0R12*****-part6 -> ../../sda6
  lrwxrwxrwx 1 root root 10 Jul  5 17:03 dm-name-swap -> ../../dm-0
  lrwxrwxrwx 1 root root  9 Jul  5 17:03 usb-Generic-_Multi-Card_201209265***00000-0:0 -> ../../sdb
  lrwxrwxrwx 1 root root  9 Jul  5 17:05 usb-SanDisk_Cruzer_Blade_000009031011200*****-0:0 -> ../../sdc
  lrwxrwxrwx 1 root root 10 Jul  5 17:05 usb-SanDisk_Cruzer_Blade_000009031011200*****-0:0-part1 -> ../../sdc1
  lrwxrwxrwx 1 root root 10 Jul  5 17:05 usb-SanDisk_Cruzer_Blade_000009031011200*****-0:0-part2 -> ../../sdc2
  lrwxrwxrwx 1 root root  9 Jul  5 17:03 wwn-0x5002538f411***** -> ../../sda
  lrwxrwxrwx 1 root root 10 Jul  5 17:03 wwn-0x5002538f411*****-part1 -> ../../sda1
  lrwxrwxrwx 1 root root 10 Jul  5 17:03 wwn-0x5002538f411*****-part2 -> ../../sda2
  lrwxrwxrwx 1 root root 10 Jul  5 17:03 wwn-0x5002538f411*****-part3 -> ../../sda3
  lrwxrwxrwx 1 root root 10 Jul  5 17:03 wwn-0x5002538f411*****-part4 -> ../../sda4
  lrwxrwxrwx 1 root root 10 Jul  5 17:03 wwn-0x5002538f411*****-part5 -> ../../sda5
  lrwxrwxrwx 1 root root 10 Jul  5 17:03 wwn-0x5002538f411*****-part6 -> ../../sda6

For example, here I can see that the links to my USB drive are labeled ``usb-SanDisk_Cruzer_Blade*``, and point to
``../../sdc``, or in other words, ``/dev/sdc``.

To install the image onto your USB drive, we will be using the :manpage:`dd(1)` command. In this case, assuming that
the image has been downloaded to ``~/Downloads/debian-live-11.5.0-amd64-kde.iso``, the command to copy the image onto
the USB drive would be::

  sudo dd bs=4M if=~/Downloads/debian-live-11.5.0-amd64-kde.iso of=/dev/sdc conv=fdatasync status=progress

.. warning::

  If you enter the wrong parameters, you can easily direct it to overwrite any of the other drives on your system. Make
  sure that you have correctly identified your USB drive and nowhere else.

Once the command completes, you can remove the USB drive and use it to boot the machine that you want to install
ZFSBootMenu on. If the computer doesn't boot from the USB drive, check your BIOS system settings as described above, and
make sure that USB booting is enabled and is the first boot option in your BIOS boot menu.

.. _config-live-usb:

Configuring the live USB drive
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

After we have used the live USB drive to boot the machine that you want to install ZFSBootMenu on, we need to install
ZFS in the live environment so that we can create our pool and datasets. We need to do this from the command line, so
open a terminal emulator. You should be able to locate the terminal program under the applications menu, or by using the
distribution's desktop search function. On Debian, you can also open a terminal by pressing the keys
``[CTRL]+[ALT]+[t]``.

Once the termial is open, acquire a root shell by typing ``sudo -s``.

Use SSH to connect to the newly booted live environment from another machine (Optional)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

If you don't have a local console for the machine that you are configuring, or if you want to be able to more easily cut
and paste information from another machine, it might be helpful to set up the live USB environment so that you can SSH
into it from another machine, and then perform the rest of this installation over that SSH link.

To intall an SSH server, we first we need to update the package lists for the live USB environment with ``apt update``.
Then we can install the SSH server::

  apt install openssh-server

And start it::

  systemctl start sshd

and we can check it's listening for connections with ``lsof``::

  root@debian:/home/user# lsof -i
  COMMAND    PID        USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
  avahi-dae 1062       avahi   12u  IPv4  12020      0t0  UDP *:mdns
  ...
  sshd      2756        root    3u  IPv4  22629      0t0  TCP *:ssh (LISTEN)
  sshd      2756        root    4u  IPv6  22631      0t0  TCP *:ssh (LISTEN)

Then we can check what dynamic ip address the live USB environment has been assigned using the ``ip`` command::

  root@debian:/home/user# ip a
  1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
      link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
      inet 127.0.0.1/8 scope host lo
         valid_lft forever preferred_lft forever
      inet6 ::1/128 scope host 
         valid_lft forever preferred_lft forever
  2: ens2f0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
      link/ether 3c:a8:2a:e4:a5:68 brd ff:ff:ff:ff:ff:ff
      altname enp2s0f0
  3: ens2f1: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
      link/ether 3c:a8:2a:e4:a5:69 brd ff:ff:ff:ff:ff:ff
      altname enp2s0f1
  4: ens2f2: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
      link/ether 3c:a8:2a:e4:a5:6a brd ff:ff:ff:ff:ff:ff
      altname enp2s0f2
  5: ens2f3: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
      link/ether 3c:a8:2a:e4:a5:6b brd ff:ff:ff:ff:ff:ff
      altname enp2s0f3
  6: eno1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
      link/ether 4c:cc:6a:32:40:00 brd ff:ff:ff:ff:ff:ff
      altname enp0s31f6
      inet 10.0.0.192/24 brd 10.0.0.255 scope global dynamic noprefixroute eno1
         valid_lft 358sec preferred_lft 358sec
      inet6 fe80::fc9d:432b:ed59:f633/64 scope link noprefixroute 
         valid_lft forever preferred_lft forever

Here we can see that on our test machine, entry number 6 in the interface list has been assigned an inet address of
``10.0.0.192`` which we can use to connect from another machine via ssh.

On the Debian Bullseye live USB we are using for these examples, the username for the ssh connection is ``user`` and the
password is ``live``. Use the ip address of the live environment, along with this username and password to ssh from
another machine back into the machine that you are installing ZFSBootMenu on. Once you have connected, you then need to
run ``sudo -s`` again to switch to the root user in the ssh session.

.. _install-zfs-debootstrap:

Install ZFS and Debootstrap in the live environment
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Before we install ZFS, we can optionally edit the live environment's package sources to ensure that we get the latest
stable version of ZFS. Since we are using Debian 11, we're going to add the ``backports`` repository so that we can get
ZFS 2.1.5. To enable this, edit the file ``/etc/apt/sources.list`` to contain only the followng lines::

  deb http://deb.debian.org/debian/ bullseye main contrib
  deb http://deb.debian.org/debian/ bullseye-backports main contrib

Then update package lists::

  apt update

If you are using a live USB that has a GNOME desktop, then you need to prevent automounting of the filesystems we are
going to be working on. This command needs to be run from that desktop, and can't be run over ssh (unless you have also
set up X11 forwarding, which we won't cover in this guide)::

  gsettings set org.gnome.desktop.media-handling automount false

The command should return silently without any error message if run from the live USB terminal application.

Now we are ready to install ZFS and the other utilities we are going to need. On Debian, we do this with apt, and use
the ``-t`` flag to specify the backports repository::

  apt install -t bullseye-backports --yes debootstrap gdisk zfsutils-linux

You can ignore any error messages about ``invoke-rc.d: policy-rc.d denied execution of start`` or
``/usr/sbin/policy-rc.d returned 101, not running 'start zfs-zed.service'``, as these are not important for the live USB
environment.

.. note::

  live USB drives do not save any configuration changes. If at any time you reboot or shut down your computer during
  this installation process, you will need to re-do the steps in this section (:ref:`config-live-usb`) every time once
  your machine has booted into the live environment. Don't worry if you forget though - you will notice immediately when
  the commands you need to run are missing!

Now that we are in a live environment with ZFS and the other tools we need installed, we can start configuring the
drives in your machine. If your drives are already correctly configured and you just want to install ZFSBootMenu into
your existing EFI partition(s), then you should skip ahead to :ref:`installing-zbm` below. Otherwise, if you want to do
a clean install of both ZFSBootMenu and a ZFS-on-Root Linux installation, then you need to wipe the disks to remove any
existing configuraton and then re-partition them, as outlined next in :ref:`partitioning-drives`.

.. _partitioning-drives:

Wiping and re-partitioning drives
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. danger::

  This will overwrite everything on the drives! Make sure there is no data on them that you want to keep!

The pool for your root dataset can be as simple or as complex as you like. Presumably anyone reading this guide is doing
so because they are already familiar with ZFS and would now like to "ZFS all the things" by putting their root
filesystem on ZFS and using ZFSBootMenu to take full advantage of its capabilites for snapshots, rollbacks, and clones.
This means that you may already have a clear vision for how you would like to partition your various storage devices and
arrange them into VDEVs and allocate cache, log, and special devices. This section of the guide shows how to set up a
single-mirror pool while leaving some space for swap, but don't be restricted by this - if you know what you would like
your pool to look like on your particular hardware, then go for it - feel free to modify the commands below to suit your
particular environment.

For this test machine we would like to use a 512MiB EFI partition. Also this machine has 32 GiB of RAM, and we would
therefore like to reserve 64 GiB (i.e. 65536 MiB) of each disk for use as mirrored swap. We would also like to follow
the ZFS convention of leaving another 8 MiB free at the end of each disk to allow for any size difference when replacing
a failed drive with an obstentiably "same sized" one that turns out not to be quite exactly the same size after all.
Apart from these 65544 MiB and the 512 MiB we used for the EFI partitions, we would like to use the entire rest of each
disk for our zpool.

We are going to clear both disks, then create all the partitions we will need before installing anything onto them.
Doing things in this order is important - if any partitions of the disks already had mounted filesystems on them when we
created a new partition, then the kernel would be unable to re-load the partition table into memory and things would get
confusing very quickly!

Creating aliases for the disks
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The first thing to do is to identify your drives and set up some shorthand names for them that we can use to save on
typing. Because we are going to be using ZFS, we want to work with drive IDs and GPT partition labels rather than drive
letters like ``/dev/sda``, because IDs and partition labels are consistent across reboots, and when used correctly can
make it much easier to identify which physical drive you need to replace if one fails. 

List the IDs of the drives on your machine::

  ls -l /dev/disk/by-id

This will show a list of ID aliases for your drives. Here is some example output from our test machine::

  root@debian:~$ ls -l /dev/disk/by-id
  total 0
  lrwxrwxrwx 1 root root  9 Jul 11 01:14 ata-Samsung_SSD_870_EVO_1TB_S5Y2NF0****124A -> ../../sda
  lrwxrwxrwx 1 root root 10 Jul 11 01:14 ata-Samsung_SSD_870_EVO_1TB_S5Y2NF0****124A-part1 -> ../../sda1
  lrwxrwxrwx 1 root root 10 Jul 11 01:14 ata-Samsung_SSD_870_EVO_1TB_S5Y2NF0****124A-part2 -> ../../sda2
  lrwxrwxrwx 1 root root 10 Jul 11 01:14 ata-Samsung_SSD_870_EVO_1TB_S5Y2NF0****124A-part3 -> ../../sda3
  lrwxrwxrwx 1 root root 10 Jul 11 01:14 ata-Samsung_SSD_870_EVO_1TB_S5Y2NF0****124A-part4 -> ../../sda4
  lrwxrwxrwx 1 root root 10 Jul 11 01:14 ata-Samsung_SSD_870_EVO_1TB_S5Y2NF0****124A-part5 -> ../../sda5
  lrwxrwxrwx 1 root root 10 Jul 11 01:14 ata-Samsung_SSD_870_EVO_1TB_S5Y2NF0****124A-part6 -> ../../sda6
  lrwxrwxrwx 1 root root 11 Jul 11 01:14 md-name-workstation:0 -> ../../md127
  lrwxrwxrwx 1 root root 11 Jul 11 01:14 md-uuid-d0211bcf:072ed587:f40118a0:2a5f0618 -> ../../md127
  lrwxrwxrwx 1 root root 13 Jul 11 01:14 nvme-eui.00000000000000000026b768****3665 -> ../../nvme0n1
  lrwxrwxrwx 1 root root 15 Jul 11 01:14 nvme-eui.00000000000000000026b768****3665-part1 -> ../../nvme0n1p1
  lrwxrwxrwx 1 root root 15 Jul 11 01:14 nvme-eui.00000000000000000026b768****3665-part2 -> ../../nvme0n1p2
  lrwxrwxrwx 1 root root 15 Jul 11 01:14 nvme-eui.00000000000000000026b768****3665-part3 -> ../../nvme0n1p3
  lrwxrwxrwx 1 root root 15 Jul 11 01:14 nvme-eui.00000000000000000026b768****3665-part4 -> ../../nvme0n1p4
  lrwxrwxrwx 1 root root 15 Jul 11 01:14 nvme-eui.00000000000000000026b768****3665-part5 -> ../../nvme0n1p5
  lrwxrwxrwx 1 root root 15 Jul 11 01:14 nvme-eui.00000000000000000026b768****3665-part6 -> ../../nvme0n1p6
  lrwxrwxrwx 1 root root 13 Jul 11 01:14 nvme-KINGSTON_SNVS1000GB_50026B76****5366 -> ../../nvme0n1
  lrwxrwxrwx 1 root root 15 Jul 11 01:14 nvme-KINGSTON_SNVS1000GB_50026B76****5366-part1 -> ../../nvme0n1p1
  lrwxrwxrwx 1 root root 15 Jul 11 01:14 nvme-KINGSTON_SNVS1000GB_50026B76****5366-part2 -> ../../nvme0n1p2
  lrwxrwxrwx 1 root root 15 Jul 11 01:14 nvme-KINGSTON_SNVS1000GB_50026B76****5366-part3 -> ../../nvme0n1p3
  lrwxrwxrwx 1 root root 15 Jul 11 01:14 nvme-KINGSTON_SNVS1000GB_50026B76****5366-part4 -> ../../nvme0n1p4
  lrwxrwxrwx 1 root root 15 Jul 11 01:14 nvme-KINGSTON_SNVS1000GB_50026B76****5366-part5 -> ../../nvme0n1p5
  lrwxrwxrwx 1 root root 15 Jul 11 01:14 nvme-KINGSTON_SNVS1000GB_50026B76****5366-part6 -> ../../nvme0n1p6
  lrwxrwxrwx 1 root root  9 Jul 11 01:14 usb-Generic-_Multi-Card_20120926571200000-0:0 -> ../../sdc
  lrwxrwxrwx 1 root root  9 Jul 11 01:14 usb-SanDisk_Cruzer_Blade_000009031011****1653-0:0 -> ../../sdb
  lrwxrwxrwx 1 root root 10 Jul 11 01:14 usb-SanDisk_Cruzer_Blade_000009031011****1653-0:0-part1 -> ../../sdb1
  lrwxrwxrwx 1 root root 10 Jul 11 01:14 usb-SanDisk_Cruzer_Blade_000009031011****1653-0:0-part2 -> ../../sdb2
  lrwxrwxrwx 1 root root  9 Jul 11 01:14 wwn-0x5002538f4112d30f -> ../../sda
  lrwxrwxrwx 1 root root 10 Jul 11 01:14 wwn-0x5002538f4112d30f-part1 -> ../../sda1
  lrwxrwxrwx 1 root root 10 Jul 11 01:14 wwn-0x5002538f4112d30f-part2 -> ../../sda2
  lrwxrwxrwx 1 root root 10 Jul 11 01:14 wwn-0x5002538f4112d30f-part3 -> ../../sda3
  lrwxrwxrwx 1 root root 10 Jul 11 01:14 wwn-0x5002538f4112d30f-part4 -> ../../sda4
  lrwxrwxrwx 1 root root 10 Jul 11 01:14 wwn-0x5002538f4112d30f-part5 -> ../../sda5
  lrwxrwxrwx 1 root root 10 Jul 11 01:14 wwn-0x5002538f4112d30f-part6 -> ../../sda6

Here we can see:

1. our install USB stick ``/dev/sdb``,  which is also shown as ``usb-SanDisk_Cruzer_Blade...``, and that has two
   partitions on it (``-part1`` and ``-part2``)
2. a built-in card reader device ``/dev/sdc``, which is also shown as ``usb-Generic-_Multi-Card...``
3. an mdraid array ``/dev/md127``, which is also shown as ``md-name-workstation:0`` and also shown as
   ``md-uuid-d0211b...``
4. a SATA SSD ``/dev/sda`` which is also shown as ``ata-Samsung_SSD_870_EVO_1TB`` and also shown as
   ``wwn-0x5002538f4112d30f``, and that has six partitions on it already (``-part1`` through ``-part6``)
5. an NVMe SSD ``/dev/nvme0n1`` which is also shown as ``nvme-KINGSTON_SNVS1000GB...`` and also shown as
   ``nvme-eui.00000000000000000026b768...``, and that also has six partitions on it (``-part1`` through ``-part6``)

Since most ZFS users want to set up some sort of redundancy for their drives, we're going to set this machine up with
the two SSDs in a mirror, and put ZFSBootMenu on both of them, so that the machine will still boot even if one of the
drives fails. Before doing this though, we want to create shorthand variables so we can refer to the SSDs with less
typing::

  disk1=/dev/disk/by-id/ata-Samsung_SSD_870_EVO_1TB_S5Y2NF0****124A
  disk2=/dev/disk/by-id/nvme-KINGSTON_SNVS1000GB_50026B76****5366

(you should of course change the drive IDs above to match your own drives)

Here we are using the ID of the whole disk, rather than one of the partition IDs that have ``-part*`` at the end. We are
also using the serial-number based IDs rather than the GUID based ``wwn`` or ``nvme-eui`` IDs, since these IDs are
easier to map to the physical drive labels when trying to find a particular physical drive inside your computer case.

Removing any previous configuration from disks
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Now that we have identified the disks we want to use and created shorthand variables for them, we need to remove any
existing configuration from them. Depending on what your disks have been used for, this might consist of swap
partitions, mdraid arrays, or labels from previous ZFS configurations. 

The first thing to do is to disable any swap partitions that might have been mounted by the live USB environment::

  swapoff --all

The next thing to do is to see if any disks have been used for ``mdraid`` arrays. On our test machine, we saw above that
``ls -l /dev/disk/by-id`` showed an mdraid device ``md127``. Another way to check for mdraid devices is by looking in
the ``/proc/mdstat`` file. On this test machine, its contents are::

  root@debian:/home/user# cat /proc/mdstat
  Personalities : [raid1] [linear] [multipath] [raid0] [raid6] [raid5] [raid4] [raid10] 
  md127 : active (auto-read-only) raid1 sda2[1] nvme0n1p2[0]
        67042304 blocks super 1.2 [2/2] [UU]

  unused devices: <none>

Here we can see that ``/dev/md127`` is a RAID-1 device made out of the partitions ``/dev/sda2`` and ``/dev/nvme0n1p2``.

We need to remove this array before continuing. We first need to make sure the ``mdadm`` tool is installed::

  apt install --yes mdadm

Then we can stop the mdraid array::

  mdadm --stop /dev/md127

and it should report the array has stopped::

  mdadm: stopped /dev/md127

You can confirm this with ``ls -l /dev/disk/by-id`` again if you want to. Now that the array is stopped, we can destroy
it on each of the partitions. For convenience we can just use the ``/dev/sd*`` style names from ``/proc/mdstat``::

  mdadm --zero-superblock --force /dev/sda2
  mdadm --zero-superblock --force /dev/nvme0n1p2

These commands always completes silently, so you should check the results with ``cat /proc/mdstat`` to make sure you
removed the superblocks from the right partitions::

  root@debian:/home/user# cat /proc/mdstat
  Personalities : [raid1] [linear] [multipath] [raid0] [raid6] [raid5] [raid4] [raid10] 
  unused devices: <none>

The last thing we need to do is clear any ZFS labels that are associated with either whole disk::

  zpool labelclear -f $disk1
  zpool labelclear -f $disk2

You will receive a ``failed to clear label`` message if the disks have not been used directly as VDEVs in a previous
zpool.

Wipe the partition tables
^^^^^^^^^^^^^^^^^^^^^^^^^

Now we have dealt with swap and mdraid, we can use the :manpage:`sgdisk(8)` command to wipe the partition tables on
the disks::

  sgdisk --zap-all $disk1
  sgdisk --zap-all $disk2

This should report that the partitions have been destroyed::

  root@debian:/home/user# sgdisk --zap-all $disk1
  GPT data structures destroyed! You may now partition the disk using fdisk or other utilities.
  root@debian:/home/user# sgdisk --zap-all $disk2
  GPT data structures destroyed! You may now partition the disk using fdisk or other utilities.

Create EFI Partitions
^^^^^^^^^^^^^^^^^^^^^

Now we can create a new EFI partition on each of the disks with :manpage:`sgdisk(8)`. We do this with the following
commands::

  sgdisk -n1:1M:+512M -t1:EF00 -c1:"EFI-0-SATA" $disk1
  sgdisk -n1:1M:+512M -t1:EF00 -c1:"EFI-1-NVMe" $disk2

The names used here are chosen to make it easy to understand the purpose of the partition, and also to identify the
physical drive the partition is on. These are EFI System Partitions, so the names start with ``EFI-0`` and ``EFI-1``,
respectively. The last part of the name, ``SATA`` or ``NVMe``, is intended to make it easy to find the physical drive
that the partition is on. When looking inside the computer case, the most obvious difference between the two drives is
that one is a 2.5-inch SATA drive and the other is an M.2 NVMe drive on a PCIe adapter card. If both drives were of the
same type, it would make more sense to use another obvious feature like the brand name on the label (here Kingston or
Samsung), or if the drives were the same make and model, you could use the last 4 digits of the serial number instead
(124A or 5366 for these two drives).

The ``sgdisk`` commands may give some warnings about the empty partition table that we were left with after the
``sgdisk --zap-all`` command, but these can be ignored::

  Warning: Partition table header claims that the size of partition table
  entries is 0 bytes, but this program  supports only 128-byte entries.
  Adjusting accordingly, but partition table may be garbage.
  Warning: Partition table header claims that the size of partition table
  entries is 0 bytes, but this program  supports only 128-byte entries.
  Adjusting accordingly, but partition table may be garbage.
  Creating new GPT entries in memory.
  Setting name!
  partNum is 0
  The operation has completed successfully.
  Warning: Partition table header claims that the size of partition table
  entries is 0 bytes, but this program  supports only 128-byte entries.
  Adjusting accordingly, but partition table may be garbage.
  Warning: Partition table header claims that the size of partition table
  entries is 0 bytes, but this program  supports only 128-byte entries.
  Adjusting accordingly, but partition table may be garbage.
  Creating new GPT entries in memory.
  Setting name!
  partNum is 0
  The operation has completed successfully.

If you want, you can see the named partitions in ``/dev/disk/by-partlabel``::

  root@debian:/home/user# ls -l /dev/disk/by-partlabel
  total 0
  lrwxrwxrwx 1 root root 10 Jul 12 04:41 EFI-0-SATA -> ../../sda1
  lrwxrwxrwx 1 root root 15 Jul 12 04:37 EFI-1-NVMe -> ../../nvme0n1p1

Create ZPool Partitions
^^^^^^^^^^^^^^^^^^^^^^^

Now we can create the ZPool partitions. The :manpage:`sgdisk(8)` commands to create the partitions for the pool are::

  sgdisk -n2:0:-65544M -t2:BF00 -c 2:"Root-0-SATA" $disk1
  sgdisk -n2:0:-65544M -t2:BF00 -c 2:"Root-1-NVMe" $disk2

This time we are not operating on an empty partition table, so ``sgdisk`` should complete the operations without any
warnings::

  Setting name!
  partNum is 1
  The operation has completed successfully.
  Setting name!
  partNum is 1
  The operation has completed successfully.

Once again you can check the result in ``/dev/disk/by-partlabel`` if you want:

  root@debian:/home/user# ls -l /dev/disk/by-partlabel/
  total 0
  lrwxrwxrwx 1 root root 10 Jul 12 04:50 EFI-0-SATA -> ../../sda1
  lrwxrwxrwx 1 root root 15 Jul 12 04:52 EFI-1-NVMe -> ../../nvme0n1p1
  lrwxrwxrwx 1 root root 10 Jul 12 04:50 Root-0-SATA -> ../../sda2
  lrwxrwxrwx 1 root root 15 Jul 12 04:52 Root-1-NVMe -> ../../nvme0n1p2


Create Swap Partitions
^^^^^^^^^^^^^^^^^^^^^^

Now we can create the swap partitions::

  sgdisk -n3:0:+64G -t3:8200 -c 3:"Swap-0-SATA" $disk1
  sgdisk -n3:0:+64G -t3:8200 -c 3:"Swap-1-NVMe" $disk2

We are not operating on an empty partition table, so sgdisk should complete the operations without any warnings::

  Setting name!
  partNum is 2
  The operation has completed successfully.
  Setting name!
  partNum is 2
  The operation has completed successfully.

Then we can check the result in ``/dev/disk/by-partlabel``::

  root@test-machine:~# ls -l /dev/disk/by-partlabel/
  total 0
  lrwxrwxrwx 1 root root 10 Aug 26 13:29 EFI-0-SATA -> ../../sda1
  lrwxrwxrwx 1 root root 15 Aug 26 13:29 EFI-1-NVMe -> ../../nvme0n1p1
  lrwxrwxrwx 1 root root 10 Aug 26 13:29 Root-0-SATA -> ../../sda2
  lrwxrwxrwx 1 root root 15 Aug 26 13:29 Root-1-NVMe -> ../../nvme0n1p2
  lrwxrwxrwx 1 root root 10 Aug 26 13:29 Swap-0-SATA -> ../../sda3
  lrwxrwxrwx 1 root root 15 Aug 26 13:29 Swap-1-NVMe -> ../../nvme0n1p3

Clear any ZFS labels from re-used disks
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

If your disks have previously been used for another installation that had the same partition sizes and used ZFS, then
there is a chance that the ZFS labels from that old system will still be on disk and will be coincidentally located at
the correct positions to mark your new partitions as being part of an old and now non-existent ZPool. This is definitely
the case on our test machine, as it has been used to test this guide multiple times, and the partitions have been
created at the same locations on disk each time.

The commands to clear any ZFS labels from our new partitions are::

  zpool labelclear -f /dev/disk/by-partlabel/EFI-0-SATA
  zpool labelclear -f /dev/disk/by-partlabel/EFI-1-NVMe
  zpool labelclear -f /dev/disk/by-partlabel/Root-0-SATA
  zpool labelclear -f /dev/disk/by-partlabel/Root-1-NVMe
  zpool labelclear -f /dev/disk/by-partlabel/Swap-0-SATA
  zpool labelclear -f /dev/disk/by-partlabel/Swap-1-NVMe

You will receive a ``failed to clear label`` message for the partitions that do not coincidentally have ZFS label
information on them.

.. _installing-zbm:

Installing ZFSBootMenu on an EFI System Partition and registering it with your computer's firmware
--------------------------------------------------------------------------------------------------

Download the pre-built ZFSBootMenu EFI executable (or customize your own)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Once you have your EFI System partitions set up, you can install ZFSBootMenu EFI executables on them. The ZFSBootMenu
project provides a pre-built image that you can download, or alternatively you may want to :doc:`build your own image
</guides/general/container-building>`. Building your own image allows you to configure things like remote access, so you
can connect to ZFSBootMenu on a remote machine as it boots, and enter a decryption password or fix boot errors or
perform rollbacks without having to worry about obtaining a remote console via IPMI or remote KVM.

For this guide we are just going to download and install the pre-built image. 

If you are performing the install via the graphical desktop of the Live USB, then launch a web browser and go to the
`ZFSBootMenu release page <https://github.com/zbm-dev/zfsbootmenu/releases>`_ and scroll down to the "Assets" section
for the latest version of ZFSBootMenu, and choose the binary file you want to use. In most cases, this will be the
"release vmlinuz x86_64" one that ends in .EFI, which at the time of writing is
``zfsbootmenu-release-vmlinuz-x86_64-v2.0.0.EFI``. Click on the link to save the file.

Alternatively, if you have been using SSH to do the install, then instead you might want to visit the download site
above from your desktop machine, identify the file you need and copy its location, and then go back to your SSH terminal
and use ``wget`` or ``curl`` to download the file directly in to the live environment.

Optionally, there are instructions on `how to verify the checksum of the downloaded file
<https://github.com/zbm-dev/zfsbootmenu#signature-verification-and-prebuilt-efi-executables>`_.

.. _copy-zbm-to-efi:

Copy ZFSBootMenu onto the EFI partition(s)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Now we need to create FAT32 filesystems on the EFI partitions that we created above. To do this we need the
:manpage:`mkdosfs(8)` command which, in the case of Debian 11, is already on the live USB; if you are using a different
live environment, you may need to install it. The package you will need is probably called something like
``dosfstools``. The commands for our test machine are::

  mkdosfs -F 32 -s 1 -n EFI /dev/disk/by-partlabel/EFI-0-SATA
  mkdosfs -F 32 -s 1 -n EFI /dev/disk/by-partlabel/EFI-1-NVMe

The ``mkdosfs`` commands should report that the filesystem creation was successful::

  mkfs.fat 4.2 (2021-01-31)
  mkfs.fat 4.2 (2021-01-31)

Now we can make some temporary directories and mount the new filesystems to them::

  mkdir /tmp/efi0
  mkdir /tmp/efi1

  mount /dev/disk/by-partlabel/EFI-0-SATA /tmp/efi0
  mount /dev/disk/by-partlabel/EFI-1-NVMe /tmp/efi1

Then we can copy the EFI executable we downloaded onto the EFI filesystems::

  cp /home/user/Downloads/zfsbootmenu-release-vmlinuz-x86_64-v2.0.0.EFI /tmp/efi0/
  cp /home/user/Downloads/zfsbootmenu-release-vmlinuz-x86_64-v2.0.0.EFI /tmp/efi1/

Registering the ZFSBootMenu EFI executable with the computer's firmware
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Now that we have our EFI partitions with ZFSBootMenu, we need to register them with the computer's firmware. To do this
we need to install the :manpage:`efibootmgr(8)` utility. On Debian 11 the command to do this is::

  apt install efibootmgr

Before we register any new EFI boot options with the computer's firmware, we should check to see what old options are
already registered and remove any that we don't need. Running ``efibootmgr`` with no arguments will show a list of
already configured EFI boot options and the order in which the computer will try them at startup::

  efibootmgr

At this point, you might see an error if the computer has been booted in Legacy (MBR) mode::

  EFI variables are not supported on this system.

If this is the case, you will need to restart your computer and change the boot settings in BIOS. You do this by
pressing a key as soon as your computer starts - often the screen will have a startup message telling you what key to
press, but sometimes it just displays a logo and you will need to do a web search to find out which key it is - often
it's the ``[delete]`` key on Dell or Asus machines, the ``[Enter]`` and then ``[F1]`` key on Lenovo, or the ``[F10]`` on
HP, and so on. Different computers have different BIOS system setting menus, so you will have to figure out where the
boot settings are and then look for EFI boot options, and confirm they are enabled. If there are no EFI settings at all
and you have a very old machine, then your computer may not support EFI boot and you will have to consult a different
guide on how to set up MBR boot with ZFSBootMenu instead. You can also do a web search for your computer's user manual
if you are unsure about the BIOS setting menus or whether EFI boot is supported.

This test machine has been booted in EFI mode, so instead of an error message, we see the list of existing boot options::

  root@debian:/home/user# efibootmgr
  BootCurrent: 0013
  Timeout: 1 seconds
  BootOrder: 0013,0012,000B,0014,0009,0001,0008
  Boot0001  ubuntu
  Boot0008  Generic Usb Device
  Boot0009  CD/DVD Device
  Boot000B  Samsung SSD 870 EVO 1TB
  Boot0012  KINGSTON SNVS1000GB
  Boot0013* UEFI: SanDisk, Partition 1
  Boot0014  SanDisk

here we can see that we have seven existing boot options. The ``BootCurrent`` value of 13 shows that we are currently
booted from option ``Boot0013``, which is ``UEFI: SanDisk, Partition 1``. There are a few entries in that list that we
want to keep, namely ``Generic Usb Device``, ``CD/DVD Device``, and of course the option we are booted into. Everything
else on that list is from previous installs of different operating systems, and we should remove them. We remove the
first entry using the ``-B`` option::

  efibootmgr -b 1 -B

This will remove the first boot option and re-display the list::

  root@debian:/home/user# efibootmgr -b 1 -B
  BootCurrent: 0013
  Timeout: 1 seconds
  BootOrder: 0013,0012,000B,0014,0009,0008
  Boot0008  Generic Usb Device
  Boot0009  CD/DVD Device
  Boot000B  Samsung SSD 870 EVO 1TB
  Boot0012  KINGSTON SNVS1000GB
  Boot0013* UEFI: SanDisk, Partition 1
  Boot0014  SanDisk

We can then remove the other options we don't want::

  efibootmgr -b B -B
  efibootmgr -b 12 -B
  efibootmgr -b 14 -B

And we will then be left with just the 3 existing options we want to preserve::

  root@debian:/home/user# efibootmgr -b 14 -B
  BootCurrent: 0013
  Timeout: 1 seconds
  BootOrder: 0013,0009,0008
  Boot0008  Generic Usb Device
  Boot0009  CD/DVD Device
  Boot0013* UEFI: SanDisk, Partition 1

Now we can add our new EFI partitions. We are going to identify them to the efibootmgr command using their current
``/dev/sd*`` and ``/dev/nvme*`` names, so let's look at the ``partlabel`` list to refresh our memory::

  ls -l /dev/disk/by-partlabel

We can see that the two drives we need are ``/dev/sda`` and ``/dev/nvme0n1``, and the the EFI partition is p1 on both of
them::

  lrwxrwxrwx 1 root root 10 Jul 17 21:24 EFI-0-SATA -> ../../sda1
  lrwxrwxrwx 1 root root 15 Jul 17 21:24 EFI-1-NVMe -> ../../nvme0n1p1

Therefore the commands to register our partitons with the computer's firmware are::

  efibootmgr -c -d /dev/sda -p 1 -L "ZFSBootMenu (SATA)" -l \\zfsbootmenu-release-vmlinuz-x86_64-v2.0.0.EFI
  efibootmgr -c -d /dev/nvme0n1 -p 1 -L "ZFSBootMenu (NVMe)" -l \\zfsbootmenu-release-vmlinuz-x86_64-v2.0.0.EFI

On our test machine, we can see that the new boot options have been created with ids 0 and 1, and that the ``BootOrder``
lists them as the first two options that the firmware will try to boot from on startup::

  BootCurrent: 0013
  Timeout: 1 seconds
  BootOrder: 0001,0000,0013,0009,0008
  Boot0000* ZFSBootMenu (SATA)
  Boot0001* ZFSBootMenu (NVMe)
  Boot0008  Generic Usb Device
  Boot0009  CD/DVD Device
  Boot0013* UEFI: SanDisk, Partition 1

This is not a good idea. If at some future point we want to boot from a live USB (``Boot0008``) again or from a DVD
(``Boot0009``), then just inserting the USB of DVD would not be enough, since these options are at the end of the
BootOrder list and the computer would boot to one of our new options before getting to them. To fix this, we can change
the BootOrder so that the computer will try the ZFSBootMenu EFI partitions only after trying removable media. To reorder
boot options, use the ``-o`` flag for ``efibootmgr``::

  root@debian:/home/user# efibootmgr -o 8,13,9,0,1
  BootCurrent: 0013
  Timeout: 1 seconds
  BootOrder: 0008,0013,0009,0000,0001
  Boot0000* ZFSBootMenu (SATA)
  Boot0001* ZFSBootMenu (NVMe)
  Boot0008  Generic Usb Device
  Boot0009  CD/DVD Device
  Boot0013* UEFI: SanDisk, Partition 1

Next steps
~~~~~~~~~~

If you are installing ZFSBootMenu to replace another bootloader such as GRUB on a machine that has an existing
Root-on-ZFS environment, then the process is now complete. You should be able to reboot the machine and it should
display the ZFSBootMenu, allowing you to select a ZFS environment or snapshot to boot into.

If however you are performing a clean install on a new machine, continue with :ref:`pool-creation` and
:ref:`install-linux` below.

.. _pool-creation:

Creating a Pool and Datasets for Root-on-ZFS installation
---------------------------------------------------------

When ZFSBootMenu starts, it will find any ZFS datasets with a mountpoint of ``/`` that also contain a Linux
installation, and will present you with a menu to select between them. For this to work on a new machine, you of course
need to create a ZFS dataset (which is described in this section) and then install a Linux environment onto it (which is
described in :ref:`install-linux` below).

Creating a Pool
~~~~~~~~~~~~~~~

For this test machine, We are are going to use ZFS native encryption to protect the root dataset. When booting from an
encrypted root dataset, ZFSBootMenu will prompt you to enter the decryption key so it can access the Linux kernel and
Initial RAM Filesystem (initramfs). These both get loaded into memory and ZFSBootMenu then hands control over to the
Linux kernel, but there is no way that ZFSBootMenu can securely provide the decryption key to the Linux Kernel. This
means that the kernel will need to prompt you again so it can have the decryption key too. But having to enter your
password twice is not a good user experience, and we are going to solve this issue by securely storing the decryption
key in a file on the initramfs, where the kernel can access it, and setting the ``keylocation`` property of the ZFS
top-level dataset top point to this file. ZFSBootMenu will of course not be able to access this file when it starts up,
since the initramfs is stored on the encrypted dataset, but ZFSBootMenu is smart enough to resolve this paradox by
simply prompting you for the passphrase anyway.

To do this, we first create a key file with a passphrase::

  echo '<your-passphrase-here>' > /etc/zfs/zroot.key
  chmod 000 /etc/zfs/zroot.key

This creates the file in the live environment, so it will be discarded when we reboot. Further below we will copy this
file into the new encrypted ZFS filesystem that we are going to create. It will then be included in the initramfs when
we build it, and we will set file permissions within the initramfs so that the keyfile is only readable by root. 

As long as the key file and the initramfs remain on the encrypted ZFS filesystem and you do not copy them anywhere else,
then this will be a secure setup. The only attacker that would be able to access the passphrase would be one that
already had root access to the ZFS filesystem when it had already been decrypted and mounted - and that attacker would
therefore *already* have access to your data, and so the key file would be of no use to them. That is of course unless
you also use the same passphrase on other machines, so don't do that!

Now we can create our ZPool with :manpage:`zpool-create(8)`::

  zpool create -f -o ashift=12 -o autotrim=on -O encryption=aes-256-gcm \
      -O keylocation=file:///etc/zfs/zroot.key -O keyformat=passphrase \
      -O acltype=posixacl -O xattr=sa \
      -O compression=lz4 -m none -R /mnt \
      rpool \
          mirror \
              /dev/disk/by-partlabel/Root-0-SATA \
              /dev/disk/by-partlabel/Root-1-NVMe

If you don't want to use ZFS native encryption, then just leave out the ``-O encryption=on``,
``-O keylocation=file:///etc/zfs/zroot.key``, and ``-O keyformat=passphrase`` options.

If you run the ``zpool create`` command and suddenly find that none of your shell commands work any more, it's probably
because you left out the ``-R`` option, and you will therefore need to reboot and reinstall ZFS in the live USB
environment and create your diskname variables again, and then ``zpool import`` your new pool, remembering to use the
``-R`` option this time! You can then continue from this point, as all of the partitioning you did above will have been
persisted to your drives.

.. note::

  Because the live USB environment does not preserve any changes across reboots, if you do reboot you will then have to
  re-import your zpool with ``zpool import -f -R /mnt -N rpool`` before continuing with this guide. The ``-N`` option
  prevents filesystems from automatically mounting, while the ``-f`` option will override any "in use" checks and import
  the pool even if it was not cleanly exported.

``zpool list`` now shows our new pool::

  root@debian:/home/user# zpool list
  NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
  rpool   864G   564K   864G        -         -     0%     0%  1.00x    ONLINE  /mnt

.. _create-datasets:

Creating datasets
~~~~~~~~~~~~~~~~~

The main benefit of ZFSBootMenu is the ability to boot into previous or alternative versions of your linux installation.
ZFSBootMenu does this by selecting a particular dataset or snapshot to mount at ``/`` and boot from. Because of this,
it's important that all the different directories that together make up a Linux installation are all stored on the same
dataset or snapshot, so that it is not possible to create a situation where different parts of the Linux installation
have been read from from different snapshots or datasets, and are incompatible.

For similar reasons, there are some things that should not change regardless of which snapshot or dataset you boot from,
such as the system logs and your home directory. These should be on separate datasets, so that even if you have to "roll
back" to an earlier version of your Linux installation, you do not lose any data.

For this test machine, the datasets we are going to create are:

========================  ===================  ===========  ============================
dataset                   mountpoint           canmount      purpose
========================  ===================  ===========  ============================
``rpool/debian``          ``/``                ``noauto``   This is our "Linux installation". It's set to
                                                            ``canmount=noauto`` in case we want to have other linux
                                                            installations on the same pool, and allow ZFSBootMenu to
                                                            select between them. The distribution initramfs will
                                                            directly mount the right root filesystem without relying on
                                                            ZFS auto-mount mechanisms.
``rpool/home``            ``/home``            ``on``       User home directories. Having these in a separate dataset
                                                            means that we can switch between different Linux
                                                            environments or roll back to a previous version of an
                                                            environment without losing any of our user data.
``rpool/home/root``       ``/root``            ``on``       Home directory for root user. Mounted at ``/root`` but
                                                            exists as a dataset under ``rpool/home`` so that it can be
                                                            managed, backed up, or replicated along with other home
                                                            directories.
``rpool/home/testuser``   ``/home/testuser``   ``on``       Home directory for a standard user account we will create in
                                                            a later step. Exists as a separate dataset under
                                                            ``rpool/home`` so that it can be managed, backed up, or
                                                            replicated independently of other home directories.
``rpool/var``             ``/var``             ``off``      Dataset that holds directories with variable data, such as
                                                            logs, mail, print jobs etc. It will not be mounted directly
                                                            and we don't store anything directly in it, however it
                                                            allows us to manage all of its subdirectories together in
                                                            terms of setting ZFS properties, replication, etc.
``rpool/var/cache``       ``/var/cache``       ``on``       Dataset that holds directories with cache data, allowing
                                                            them to be managed separately from other parts of ``/var``
``rpool/var/log``         ``/var/log``         ``on``       Dataset that holds directories with log data, allowing them
                                                            to be managed separately from other parts of ``/var``
``rpool/var/mail``        ``/var/mail``        ``on``       Dataset that holds directories with mail data, allowing them
                                                            to be managed separately from other parts of ``/var``
``rpool/var/spool``       ``/var/spool``       ``on``       Dataset that holds directories with printer and other spool
                                                            data, allowing them to be managed separately from other
                                                            parts of ``/var``
``rpool/var/tmp``         ``/var/tmp``         ``on``       Dataset that holds directories with temporary application
                                                            data, allowing them to be managed separately from other
                                                            parts of ``/var``
========================  ===================  ===========  ============================

The commands to create and mount these datasets are::

  zfs create -o mountpoint=/ -o canmount=noauto rpool/debian
  zfs mount rpool/debian
  zfs create -o mountpoint=/home rpool/home
  zfs create -o mountpoint=/root rpool/home/root
  zfs create rpool/home/testuser
  zfs create -o canmount=off -o mountpoint=/var rpool/var
  zfs create rpool/var/log
  zfs create rpool/var/spool
  zfs create rpool/var/mail
  zfs create rpool/var/cache
  zfs create rpool/var/tmp

You will of course want to replace ``testuser`` with the ID of the user account you want to create for your
installation.

Note that ``rpool/debian`` was mounted before the other datasets were created. This is because ``canmount=noauto``
causes it not to be mounted automatically, yet it should be mounted before the other datasets because its mountpoint is
``/``, and mounting it after the other datasets would therefore "shadow" them, making them invisible. Since most of the
other datasets do not specify a ``canmount`` value, they will be mounted when created, therefore ``rpool/debian`` must
be mounted before the other datasets are created.

The children of ``rpool/var`` will inherit the ``/var`` mountpoint and add their own name at the end, so it is not
necessary to specify a mountpoint for these filesystems.

These commands should return silently without error. We can then list our new datasets::

  root@debian:/home/user# zfs list
  NAME                  USED  AVAIL     REFER  MOUNTPOINT
  rpool                 228M   837G      192K  none
  rpool/debian          169M   837G      169M  /mnt
  rpool/home            592K   837G      200K  /mnt/home
  rpool/home/root       200K   837G      200K  /mnt/root
  rpool/home/testuser   192K   837G      192K  /mnt/home/testuser
  rpool/var            54.8M   837G      192K  /mnt/var
  rpool/var/cache      53.6M   837G     53.6M  /mnt/var/cache
  rpool/var/log         416K   837G      416K  /mnt/var/log
  rpool/var/mail        192K   837G      192K  /mnt/var/mail
  rpool/var/spool       280K   837G      280K  /mnt/var/spool
  rpool/var/tmp         192K   837G      192K  /mnt/var/tmp

The mountpoints shown are all under ``/mnt``, due to the ``-R /mnt`` flag that we used when creating the pool. This will
go away when we reboot or re-import the pool, and the mountpoints will be directly under ``/``.

.. note::

  If you need to reboot after creating these datasets, then you will need to mount them once the live USB environment
  has started and you have installed the ZFS packages and imported the pool, by running ``zfs mount rpool/debian`` and
  then ``zfs mount -a``. If you have used ZFS native encryption as shown above, then you will need to run
  ``zfs load-key rpool`` before mounting, and then run the two mount commands.

We also need to secure the ``/root`` directory. It's currently mounted at ``/mnt/root``, so run::

  chmod 700 /mnt/root

When we install our Linux environment in :ref:`install-linux` below, any system directories other than the ``home`` and
``var`` children listed above will end up on the ``rpool/debian`` dataset. This means that if we take a snapshot of
``rpool/debian`` and then later use ZFSBootMenu to boot from that snapshot, all of those system directories will come
from the same snapshot and will be consistent with each other.

.. _install-linux:

Installing a Linux environment on the dataset
---------------------------------------------

Before installing a Linux environment, all datasets that the environment should go onto must be mounted under a
temporary non-root mountpoint. For the rest of this section, it's assumed the temporary mountpoint is ``/mnt``. If you
have just created a zpool and dataset by following section 2 above, then you will already have ``rpool/debian`` mounted
at ``/mnt`` as well as ``rpool/home`` mounted under ``/mnt/home``, ``rpool/var/log`` mounted at ``/mnt/var/log``, and so
on. If instead you are working with different datasets, ensure that they are correctly mounted under ``/mnt`` before
proceeding with this section.

Installing the operating system files onto the datasets
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

There are a number of ways to copy operating system files onto the datasets we have created. You could just copy them
across from an existing Linux environment, or even from the live USB environment itself. Alternatively, you can use a
tool provided by your distribution to copy a minimal linux installation from their servers over the network. This
produces a clean minimalist system, and we are going to do this on the test machine using the ``debootstrap`` command,
which we have already installed on the live USB envronment using apt in :ref:`install-zfs-debootstrap` above.

Before running ``debootstrap`` however, we need to create an in-memory temporary file system for the new environment
under ``/mnt/run``. The commands to do this are::

  mkdir /mnt/run
  mount -t tmpfs tmpfs /mnt/run
  mkdir /mnt/run/lock

These commands should return silently without error.

We can now run ``debootstrap`` to download a basic Debian installation to ``/mnt``. At the time of writing, the stable
Debian version is called ``bullseye``::

  debootstrap bullseye /mnt

This produces a long list of output::

  root@debian:/home/user# debootstrap bullseye /mnt
  I: Target architecture can be executed
  I: Retrieving InRelease 
  I: Checking Release signature
  I: Valid Release signature (key id A4285295FC7B1A81600062A9605C66F00D6C9793)
  I: Retrieving Packages 
  I: Validating Packages 
  . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 
  I: Unpacking the base system...
  . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 
  I: Configuring tasksel-data...
  I: Configuring tasksel...
  I: Configuring libc-bin...
  I: Base system installed successfully.

The last line of which should inform us that the system has been installed.

After the base system has been copied in, we should create a zpool cache for new environment so that it knows it is
supposed to import ``rpool`` when it starts up. We do this by defining a zpool cache for the live USB environment in
order to create the cachefile, and then copying it across to the new environment::

  zpool set cachefile=/etc/zfs/zpool.cache rpool
  mkdir -p /mnt/etc/zfs
  cp /etc/zfs/zpool.cache /mnt/etc/zfs/

Another thing that we need to do is to copy the ZFS encryption key file that we created in :ref:`pool-creation` above
onto the new dataset, so that it will be included in the initramfs when it is generated in :ref:`install-zfs-target`
below::

  cp /etc/zfs/zroot.key /mnt/etc/zfs/

.. note::

  Remember that you should never move or copy the key file off the dataset for which it contains the encryption key! It
  is only a convenience for the Linux kernel to be able to mount the encrypted dataset without having to prompt you
  again for the passphrase, and it should never be accessible without you having already entered the passphrase that it
  contains.

Configuring the new environment
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Now that we have copied in the files for our new Linux environment, we need to configure it. In order to do this, we
need to "change root", or :manpage:`chroot(1)`, in our terminal session, so that it can only see the contents of
``/mnt``, and thinks that ``/mnt`` is its root directory. Any commands we then run that alter files will silently
prepend ``/mnt`` to the front of the filename, allowing us to configure the new environment under ``/mnt`` just as if
we were working on a filesystem mounted at ``/`` instead.

Before we do this though, we need to make sure that we will still have access to the live USB's virtual filesystems
``/dev``, ``/proc``, and ``/sys`` once we have performed the ``chroot``, so that our terminal will continue to work and
so we can run all the configuation commands that we need to. We can do this by doing a "remount bind" of these
directories so that they become accessible from under ``/mnt`` as well as in their original location::

  mount --rbind /dev  /mnt/dev
  mount --rbind /proc /mnt/proc
  mount --rbind /sys  /mnt/sys

The ``--rbind`` flag tells ``mount`` that it should mirror the first directory given (``/dev``, ``/proc``, or ``/sys``)
to also be accessible under the second path (``/mnt/dev``, ``/mnt/proc``, or ``/mnt/sys`` respectively).

Now we can ``chroot`` into ``/mnt`` and continue with our configuration::

  chroot /mnt /usr/bin/env bash --login

Once the ``chroot`` has run, we can see from the change in our bash prompt that we are in the ``/`` directory of the new
environment (which is our new filesystem that we mounted at ``/mnt`` in the live USB environment)::

  root@debian:/home/user# chroot /mnt /usr/bin/env bash --login
  root@debian:/#

Configuring the hostname
^^^^^^^^^^^^^^^^^^^^^^^^

We are going to set the hostname of the test machine to "test-machine". Use your own hostname instead when configuring
your system::

  hostname test-machine
  hostname > /etc/hostname

These commands should return silently without error.

Next, we edit the file ``/etc/hosts`` and change the line for ``127.0.0.1`` to have our hostname as well::

  127.0.0.1       localhost test-machine
  ::1             localhost ip6-localhost ip6-loopback
  ff02::1         ip6-allnodes
  ff02::2         ip6-allrouters

Configure the network interface
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The first thing to do is to identify the network interface that we want to configure. We can list our network interfaces
with the ``ip`` command::

  root@debian:/# ip a
  1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
      link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
      inet 127.0.0.1/8 scope host lo
         valid_lft forever preferred_lft forever
      inet6 ::1/128 scope host 
         valid_lft forever preferred_lft forever
  2: ens2f0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
      link/ether 3c:a8:2a:e4:a5:68 brd ff:ff:ff:ff:ff:ff
      altname enp2s0f0
  3: ens2f1: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
      link/ether 3c:a8:2a:e4:a5:69 brd ff:ff:ff:ff:ff:ff
      altname enp2s0f1
  4: ens2f2: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
      link/ether 3c:a8:2a:e4:a5:6a brd ff:ff:ff:ff:ff:ff
      altname enp2s0f2
  5: ens2f3: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
      link/ether 3c:a8:2a:e4:a5:6b brd ff:ff:ff:ff:ff:ff
      altname enp2s0f3
  6: eno1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
      link/ether 4c:cc:6a:32:40:00 brd ff:ff:ff:ff:ff:ff
      altname enp0s31f6
      inet 10.0.0.192/24 brd 10.0.0.255 scope global dynamic noprefixroute eno1
         valid_lft 376sec preferred_lft 376sec
      inet6 fe80::fc9d:432b:ed59:f633/64 scope link noprefixroute 
         valid_lft forever preferred_lft forever

Here we can see that our test machine has one virtual loopback interface and five physical interfaces, only one of which
(``eno1``), is connected to a cable, and this is the one that the live USB envionment has assigned an IP address to and
is using for its networking. This is the one we want to configure for our new environment also. Debian systems created
using ``debootstrap`` use ``networking.service``. This means to configure this interface we need to create a file for it
in the ``/etc/network/interfaces.d`` directory, which in this case would be ``/etc/network/interfaces.d/eno1`` - if your
interface has a different name, then you should use that for the filename instead. We are going to edit this file to
configure the interface for DHCP - you should change this if you want a static IP or some other configuration.

The contents of ``/etc/network/interfaces.d/eno1`` on our test machine are::

  auto eno1
  iface eno1 inet dhcp

Configure package sources
^^^^^^^^^^^^^^^^^^^^^^^^^

We need to give the new environment a full list of package sources that includes ``contrib`` packages, so that it will
be able to access ZFS updates. We do this by editing ``/etc/apt/sources.list``. If you also want your system to be able
to install non-free packages, then you can also add ``non-free``. We will be doing this for this test machine as well. 

We also want to include the backports repository so that we can have the latest available version of ZFS.

The contents of ``/etc/apt/sources.list`` on our test machine are::

  deb http://deb.debian.org/debian bullseye main contrib non-free
  deb-src http://deb.debian.org/debian bullseye main contrib non-free

  deb http://deb.debian.org/debian-security bullseye-security main contrib non-free
  deb-src http://deb.debian.org/debian-security bullseye-security main contrib non-free
 
  deb http://deb.debian.org/debian bullseye-updates main contrib non-free
  deb-src http://deb.debian.org/debian bullseye-updates main contrib non-free

  deb http://deb.debian.org/debian bullseye-backports main contrib non-free
  deb-src http://deb.debian.org/debian bullseye-backports main contrib non-free

Configure system environment
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

For historic reasons, some programs look for mount information in a file called ``/etc/mtab``. These days this file
should just be a symlink to the kernel mount information that is exposed in ``/proc/self/mounts``, however this was not
set up by debootstrap, so we need to do it manually::

  ln -s /proc/self/mounts /etc/mtab

We should also set up our console and locales. First we install the packages needed::

  apt update
  apt install console-setup locales

This will prompt you to select an encoding for the console. If you don't have a particular encoding that you want to
use, then the default of ``UTF-8`` should be fine.

Then we can configure various aspects of our system. When selecting the locales for the system, you should always make
sure that you include ``en_US.UTF-8`` along with any other locales you select::

  dpkg-reconfigure locales tzdata keyboard-configuration console-setup

This will prompt you to select various options for locale, timzone, and console. Default values are generally OK if you
are unsure.

.. _install-zfs-target:

Install ZFS in the new system
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

We need the new system to support ZFS as well. First, we install dependencies that the Debian package requires:

  apt install --yes dpkg-dev linux-headers-generic linux-image-generic

.. note::

  Note that these packages were installed from the main Debian repository rather than the backports repository (because
  we did not specify ``-t backports``). This is important because the backports version of these packages may from time
  to time include a newer kernel that ZFS is not yet compatible with. For example, at the time of writing OpenZFS
  supports Linux kernels up to and including 5.18, however the backports repository contains kernel 6.0, whereas the
  main repository still contains kernel 5.10.

Then we need to make sure that the initramfs image that will be generated when we install ZFS will only be readable by
root, so that unprivileged users will not be able to read the encryption key from it::

  echo "UMASK=0077" > /etc/initramfs-tools/conf.d/umask.conf

Now we can install the ``zfs-initramfs`` package. On our test machine we want to use the backports repository so that we
can have the latest version of ZFS, so we include the ``-t bullseye-backports`` flag in the apt install command. Don't
bother with that flag if you choose not to use backports.

.. code-block::

  apt install -t bullseye-backports zfs-initramfs
  echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf

You can ignore any messages like ``modprobe: FATAL: Module zfs not found in directory /lib/modules/5.10.0-18-amd64``
that relate to the kernel version of the live environment - if you see this sort of thing, just check that you have
other messages like ``Building for 5.10.0-19-amd64`` that indicate your new chroot environment has a later kernel
version and that ZFS modules were built for it.

Installing the ``zfs-initramfs`` package rebuilds the inital RAM filesystem image as a file under ``/boot``, which in
the case of this test machine is ``/boot/initrd.img-5.10.0-19-amd64``. Because we stored our ZFS encryption key file in
``/etc/zfs/zroot.key``, it has been included in the initramfs image, and we can check this with the ``lsinitramfs``
utility that is included in the ``dracut-core`` package. First we install ``dracut-core``::

  apt install dracut-core

Then we can use ``lsinitramfs`` to list the files in the initial RAM filesystem, and check that it contains our key
file::

  lsinitramfs /boot/initrd.img-5.10.0-19-amd64 | grep zroot.key

This should show that our keyfile was found in the initramfs file::

  etc/zfs/zroot.key

Because the ``initramfs`` is mounted at ``/`` when the Linux kernel first boots, ``rpool`` will be able to find this key
file at ``file:///etc/zfs/zroot.key``, which is the ``keylocation`` for our encrypted dataset, and so ZFS will be able
to load the key and mount the dataset without prompting us for a password.

We should also check the file's read permissions::

  ls -l /boot/initrd.img-5.10.0-19-amd64

Here you can see that it is only readable by root, which is what we want::

  -rw------- 1 root root 44872711 Nov 30 02:40 /boot/initrd.img-5.10.0-19-amd64

If instead you see that the file is readable by all users, it will be because you forgot to run
``echo "UMASK=0077" > /etc/initramfs-tools/conf.d/umask.conf`` above. You can fix this by running that command now, and
then running ``update-initramfs -u -k all``. It's important to do this rather than just running ``chmod`` on the file,
so that permissions will be preserved whenever the file is replaced due to an upgrade. Make sure to re-check the
permissions with ``ls -l`` once you have run ``update-initramfs``.

.. note::

  Remember that you should never move or copy the initramfs image off the dataset for which it contains the encryption
  key! It is only a convenience for the Linux kernel to be able to mount the encrypted dataset without having to prompt
  you again for the passphrase, and it should never be accessible without you having already entered the passphrase that
  it contains.

Set a root password (optional)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

If you want to be able to log in to the new machine as root, you will need to set a root password. Since we are
currently the root user, we can do this just with the ``passwd`` command::

  passwd

This will prompt you for a password and password confirmation.

.. _create-user:

Create a user account
^^^^^^^^^^^^^^^^^^^^^

We should create a user account for the system so that we aren't running everything as root. For the test machine, we
are going to create a user called "testuser"::

  adduser testuser

Because we already created a seperate dataset for this user in :ref:`create-datasets` above, and it is already mounted
at ``/home/testuser``, this command gives an error message that the new user's home directory already exists, and does
not set it up:

.. code-block:: none

  root@test-machine:~# adduser testuser
  Adding user `testuser' ...
  Adding new group `testuser' (1000) ...
  Adding new user `testuser' (1000) with group `testuser' ...
  The home directory `/home/testuser' already exists.  Not copying from `/etc/skel'.
  adduser: Warning: The home directory `/home/testuser' does not belong to the user you are currently creating.

It then prompts us for the user's password. Enter a password and confirm it::

  New password:
  Retype new password:
  passwd: password updated successfully

It then prompts us for informtion about the user. Enter a full name, and just press Enter to leave the rest of the
fields blank and confirm your choices::

  Changing the user information for testuser
  Enter the new value, or press ENTER for the default
          Full Name []: test user
          Room Number []:
          Work Phone []:
          Home Phone []:
          Other []:
  Is the information correct? [Y/n] y
  root@test-machine:~#

We now need to configure the user's home directory because it wasn't set up automatically. First we copy in the basic
files the user needs::

  cp -a /etc/skel/. /home/testuser

Then we need to change the ownership of the directory and the files we copied into it so that they belong to the new
user::

  chown -R testuser:testuser /home/testuser

Lastly we need to add the user to the various groups we will need::

  usermod -a -G audio,cdrom,dip,floppy,netdev,plugdev,sudo,video testuser


Install system and desktop software
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

With the basic system configured, we can now install a full set of system software, as well as a graphical desktop
environment if you want. 

First we update existing packages via apt::

  apt dist-upgrade

Then we can install a full set of software::

  tasksel --new-install

This will present a menu of options to install. Use the up and down arrow keys and space bar to select options. You
should select "standard system utilities", along with any desktop environments you want installed. Here we are just
using KDE::

  Choose software to install:

     [*] Debian desktop environment
     [ ] ... GNOME
     [ ] ... Xfce
     [ ] ... GNOME Flashback
     [*] ... KDE Plasma
     [ ] ... Cinnamon
     [ ] ... MATE
     [ ] ... LXDE
     [ ] ... LXQt
     [ ] web server
     [ ] SSH server
     [*] standard system utilities

Press ``[tab]`` to move to the ok button and press enter to install your selections.

Use an in-memory tmpfs for ``/tmp`` (optional)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

It's recommended to use an in-memory ``tmpfs`` for ``/tmp``. We can configure Debian to set this up at boot using
systemd, by copying the appropriate unit file into ``/etc/systemd/system`` and then activating it::

  cp /usr/share/systemd/tmp.mount /etc/systemd/system/
  systemctl enable tmp.mount

.. _install-ssh:

Install an SSH server (optional)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

If you are performing this installation via SSH, or if you just want to have SSH enabled, then you should install an SSH
server into the new environment as well::

  apt install openssh-server

You will be able to log in via ssh using the new user that we created in :ref:`create-user` above. We already added this
user to the sudo group, so you can switch to root with ``sudo -s`` once you are logged in.

.. _config-swap:

Configure swap (optional)
^^^^^^^^^^^^^^^^^^^^^^^^^

If you want to configure swap, you can do so in any of the ways one would normally set up swap on a new machine. On this
test machine, we are going to set up encrypted mirrored swap, since that is a good match for its encrypted mirrored root
pool.

We want to put our swap on an ``mdraid1`` device so that the machine won't crash if one the drives fails while swap is
in use. We use mdraid for instead of ZFS for this because under conditions of high memory pressure, swap can deadlock if
it's on ZFS. `You can read more about that here if you want to <https://github.com/openzfs/zfs/issues/7734>`_. We also
want to be able to encrypt our swap, so that no secrets can be recovered from it by an attacker.

First make sure that :manpage:`mdadm(8)` and :manpage:`cryptsetup(8)` are installed::

  apt install cryptsetup mdadm

If these had not already been installed, you will see that ``cryptsetup`` gets a bit confused during installation by
having ZFS as our root device, and generates a couple of error messages we can ignore::

  cryptsetup: ERROR: Couldn't resolve device rpool/debian
  cryptsetup: WARNING: Couldn't determine root device

We can then create our mirrored raid device::

  mdadm --create /dev/md0 --metadata=1.2 --level=mirror --raid-devices=2 /dev/disk/by-partlabel/Swap-0-SATA /dev/disk/by-partlabel/Swap-1-NVMe

The ``mdadm`` command should report that the device is started::

  mdadm: array /dev/md0 started.

In order for the system to correctly recognise the new raid1 array as ``/dev/md0`` on startup, we need to add an entry
that decribes it to ``/etc/mdadm.conf``. Without this entry, the system would be prone to dynamically giving the array a
different ``/dev/md***`` name, which would break references to it. We can do this by querying the details of the array
using mdadm and appending the output to the mdadm.conf file::

  mdadm --detail --scan >> /etc/mdadm/mdadm.conf

Now we have our raid1 device, we need to create an encrypted device on top of it. We can do this by appending a line to
the file ``/etc/crypttab``::

  echo "swap /dev/md0 /dev/urandom swap,cipher=aes-xts-plain64:sha256,size=512" >> /etc/crypttab

The ``/etc/crypttab`` file defines encrypted block devices that are set up when the system boots. The fields in this
``crypttab`` line are:

==================================================  ================================
field                                               meaning
==================================================  ================================
``swap``                                            The new encrypted device should be called "swap", and will be
                                                    available as ``/dev/mapper/swap``
``/dev/md0``                                        The ``/dev/md0`` array that we created should be the underlying
                                                    storage for the new encrypted block device
``/dev/urandom``                                    The encryption key for the new encrypted block device should be
                                                    read from ``/dev/urandom``, which means it will be a random string
                                                    of bytes that can't be recreated - once the machine is shut down
                                                    and this key is lost from memory, the encrypted swap contents that
                                                    are left on the drive cannot be decrypted (which is exactly what
                                                    we want)
``swap,cipher=aes-xts-plain64:sha256,size=512``     Format the new encrypted block device as swap storage. Use the
                                                    ``aes-xts-plain64:sha256`` cipher. The encryption key should be
                                                    512 bytes (so this is how many bytes will be read from
                                                    ``/dev/urandom`` to create the key)
==================================================  ================================

Now that we have defined an encrypted block device, we can specify it as our swap device by appending a line to
``/etc/fstab``::

  echo "/dev/mapper/swap none swap defaults 0 0" >> /etc/fstab

The ``/etc/fstab`` file is the main configuration file for filesystems on a linux machine. We don't need to declare
our ZFS filesystem mounts in ``/etc/fstab`` since ZFS takes care of mounting them for us, and we don't need it for our
tmpfs filesystem mounted at ``/tmp`` because that is taken care of by systemd at startup, however we do still need to
use if for swap. The fields in this fstab line are:

==================================================  ================================
field                                               meaning
==================================================  ================================
``/dev/mapper/swap``                                The block device to be mounted is the encrypted device
                                                    ``/dev/mapper/swap`` that we created above.
``none``                                            The block device should have no mountpoint (because swap is not
                                                    accessible via the filesystem)
``swap``                                            The filesystem to be mounted is of type "swap"
``defaults``                                        Use default mount options only
``0 0``                                             The dump command should not dump this filesystem, and fsck should
                                                    not be run on this filesystem at boot time.
==================================================  ================================

Then we can run ``update-initramfs`` so that the updated ``fstab`` file will be included in our initial RAM filesystem,
and will be available to the kernel at boot time.

  update-initramfs -c -k all

(you can ignore any warning messages about ``possible missing firmware for module nouveau``)

This should ensure that our mirrored swap is mounted when the system is rebooted.

If a drive in an mdraid array fails, then at next boot Systemd will keep waiting for the failed drive to appear,
delaying the boot. The default timeout for this is 90 seconds, but we can reduce this to a more reasonable 5 seconds by
creating a Systemd unit file for our mdraid device. Create the file ``/etc/systemd/system/dev-md0.device``, and give it
the following content:

.. code-block:: ini

  [Unit]
  JobRunningTimeoutSec=5

This ensures that we won't have to wait to long at boot in case of a failed drive.

Reboot into the new environment
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The new system should now be in a state that it can be booted. If you have been performing the installation via SSH,
make sure that you have completed :ref:`install-ssh` above before continuing!

Snapshot the initial installation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Before we continue, we should take a ZFS snapshot of the system state, so that we have a consistent point to reboot to
if anything goes wrong later in the installation process::

  zfs snapshot -r rpool@install


Exit the ``chroot`` environment, unmount bind filesystems, and export zpool
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

We need to exit the ``chroot`` environment in order to reboot::

  exit

We then need to release the bind mounts we made earlier under ``/mnt``, so that we will be able to export rpool without
conflicts::

  mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}

The parts of this command are:

=======================================  ==============================
part                                     meaning
=======================================  ==============================
``mount``                                List info about all mounted filesystems, one filesystem per line
``grep -v zfs``                          filter the list of filesystems to exclude any line with 'zfs' in it
``tac``                                  reverse the order of the list
``awk '/\/mnt/ {print $3}'``             filter the list down to be only the 3rd field of each line that matches the
                                         pattern ``/mnt`` - this will be the mount points of the bind mounts we made
                                         under ``/mnt``
``xargs -i{} umount -lf {}``             pass each of these mount points in turn as the argument to the command
                                         ``umount -lf``, which will lazily (``-l``) force (``-f``) un-mount the
                                         filesystem
=======================================  ==============================

We should also set a property on our ``rpool/debian`` dataset to modify the Linux kernel command line that will be used
on boot. By default, ZFSBootMenu will boot with the "quiet" option, which suppresses screen output during boot. Because
this is a new installation that we have made by hand, we actually want to see all messages on our first boot in case of
error. We can do this by setting the following::

  zfs set org.zfsbootmenu:commandline="loglevel=4" rpool/debian

You can change this back to ``org.zfsbootmenu:commandline="quiet loglevel=4"`` later if you want.

Then we need to export rpool so that the new system will be able to import it at boot time::

  zpool export -a

Reboot the system
^^^^^^^^^^^^^^^^^

We can now issue the reboot command::

  reboot

Make sure to remove the live USB stick once the machine shuts down and before it starts to boot again, so that it
reboots into the new system, rather than back into the live USB environment. If you do encounter any problems with
booting the system, then you can re-insert the live USB and powercycle the machine, then go back over this guide to see
if you can identify any missed steps or other problems. Keep in mind that if you do this you will need to re-install ZFS
in the live USB environment, as well as import rpool, load the encryption key, mount the datasets, create bind mounts,
and chroot as shown above.

If everything is OK, the system should boot into ZFSBootMenu. If you have used ZFS native encryption as suggested above,
you will first be prompted for the decryption password you used so that the ZFSBootMenu bootloader on the EFI partition
can inspect the datasets under rpool to identify any bootable Linux environments. 

ZFS Boot menu should find and present you with a single bootable option, ``rpool/debian``. There are various other
options shown at the bottom of the screen, but you can disregard them for now. Press enter to boot into the
``rpool/debian`` environment we have been configuring. If you are using ZFS encryption and you followed the steps above
for storing a key file in the initramfs image, then you should not need to enter your decryption password again, since
the kernel can access it from the keyfile in the initramfs image.

.. note::

  If you intend to connect to the newly configured machine via SSH, note that it might have a new DHCP lease and a
  different IP address once it has rebooted - use a console or the desktop environment to check what the new value is.

Once the machine has finished booting, it will display a login prompt. Log in as the user that you created above, or if
you set a root password then you can log on as the root user instead. If you forgot to create a user and forgot to set a
root password, then you are going to need to reboot back into the live USB environment, re-install ZFS in the live USB
environment, force-import rpool, load the encryption key, mount the datasets as shown above, create the bind mounts
shown above, and chroot into the new environment as shown above. Then you can create the user and set the root password.
Don't forget to correctly exit the chroot environment, release the bind mounts, and export rpool before rebooting,
otherwise you won't be able to boot back into it.

Next steps
^^^^^^^^^^

If you had any problems during installation, see the next section for troubleshooting suggestions. If you configured
swap on mdraid by following the instructions in :ref:`config-swap` above, then you should read
:ref:`swap-raid-troubleshooting` below.

Otherwise, you should now have a working root-on-ZFS Linux environment with ZFSBootMenu, congratulations!

Troubleshooting
---------------

If you are using an mdraid array for swap, it can fail to start automatically if a drive has failed. See
:ref:`swap-raid-troubleshooting` below for a workaround.

If you are encounter problems with the system not reaching ZFSBootMenu, go back over :ref:`installing-zbm` and
:ref:`pool-creation` in this guide and also consult the guide :doc:`/guides/debian/uefi-install`.

If you encounter problems with ZFSBootMenu itself, check to see if there is a similar `issue on github
<https://github.com/zbm-dev/zfsbootmenu/issues>`_. There is a search function that you can use to find similar issues.

If you encounter problems with the Linux environment booting after ZFSBootMenu, or with the state of the environment
once it has booted, review the troubleshooting section of the Root-on-ZFS guide for your distribution from the OpenZFS
project - `the Debian one is here
<https://openzfs.github.io/openzfs-docs/Getting%20Started/Debian/Debian%20Bullseye%20Root%20on%20ZFS.html#troubleshooting>`_.

.. _swap-raid-troubleshooting:

Automount degraded mdraid array for swap
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you have your swap device on an mdraid array and one of the drives that the array partitions are on fails, then the
array will not be automatically assembled at startup - and this means that swap won't be automatically started either.

You can fix this by creating a Systemd service that will check the array and swap are present, and if not, imports the
degraded mdraid array and starts swap. First, acquire a root shell:

  sudo -s

Then create the file ``/usr/local/bin/checkswap.sh``, and paste the following content in to it::

  #!/usr/bin/bash

  mdraid="/dev/md0"
  cryptdrive="/dev/dm-0"

  log(){
      logger -p $1 "$2  (from /usr/local/bin/checkswap.sh)"
  }
  info(){
      log "user.info" "$1"
  }
  err(){
      log "user.err" "$1"
  }


  if [ "$(swapon --show=NAME | tail -1)" = $cryptdrive ]
  then
      info "Swap is already active, nothing to do"
      exit 0
  fi


  if [ ! -e $mdraid ]
  then
      err "MDRaid device $mdraid is not present - can not configure swap"
      exit 1
  fi


  err "Swap was not activated at boot - attempting to activate it:"

  if [ ! $(mdadm --detail $mdraid | grep "active sync" | wc -l) -eq 1 ]
  then
      result=$(mdadm --incremental --run --scan 2>&1)
      if [ $(mdadm --detail $mdraid | grep "active sync" | wc -l) -eq 1 ]
      then
          info "mdraid device $mdraid has been activated"
      else
          err "Failed to activate mdraid device $mdraid - could not activate swap! Message was: $result"
          exit 2
      fi
  fi


  if [ ! -e $cryptdrive ]
  then
      result=$(cryptdisks_start swap 2>&1)
      if [ -e $cryptdrive ]
      then
          info "Encrypted device $cryptdrive has been set up"
      else
          err "Could not set up encrypted device $cryptdrive - could not activate swap! Message was: $result"
          exit 3
      fi
  fi


  result=$(swapon $cryptdrive) 2>&1

  if [ "$(swapon --show=NAME | tail -1)" = $cryptdrive ]
  then
      info "Swap was successfully activated"
      exit 0
  else
      err "Could not activate swap!  Message was: $result"
      exit 4
  fi

then ``chmod`` the script file to make it executable for root:

  chmod 700 /usr/local/bin/checkswap.sh

For this script to run, we need to create a Systemd service for it. Create the file
``/etc/systemd/system/checkswap.service`` and paste the following content in to it:

.. code-block:: ini

  [Unit]
  Description=Check swap and enable it if not active 
  Requires=local-fs.target
  After=local-fs.target

  [Service]
  Type=oneshot
  ExecStart=sh -c '/usr/local/bin/checkswap.sh'

  [Install]
  WantedBy=multi-user.target

Then enable the new service, so that it will run at startup::

  systemctl enable checkswap.service

Following the next and all subsequent boots, the output of this script will go to the system log, which on Debian can be
viewed using the ``journalctl`` command from a root shell::

  sudo -s
  journalctl -b

(the ``-b`` flag on the ``journalctl`` will show messages since the start of the current boot)

.. code-block::

  -- Journal begins at Wed 2022-11-30 06:13:44 UTC, ends at Wed 2022-11-30 06:14:21 UTC. --
  Nov 30 06:13:44 test-machine kernel: Linux version 5.10.0-19-amd64 (debian-kernel@lists.debian.org) (gcc-10 (Debian 10.2.1-6) 10.2.1 20210110, GNU ld (GNU Bi>
  Nov 30 06:13:44 test-machine kernel: Command line: root=zfs:rpool/debian loglevel=4 spl.spl_hostid=0x00bab10c
  Nov 30 06:13:44 test-machine kernel: x86/fpu: Supporting XSAVE feature 0x001: 'x87 floating point registers'
  ...
  Nov 30 06:13:46 test-machine root[1229]: Swap is already active, nothing to do  (from /usr/local/bin/checkswap.sh)
  ...
  Nov 30 06:13:46 test-machine systemd[1]: checkswap.service: Succeeded.

If at some point in the future you encounter a drive failure, you will be able to see messages in the journal about the
steps the script took to start swap regardless::

  sudo -s

  journalctl -b

  -- Journal begins at Wed 2022-11-30 06:21:56 UTC, ends at Wed 2022-11-30 06:22:48 UTC. --
  Nov 30 06:21:56 test-machine kernel: Linux version 5.10.0-19-amd64 (debian-kernel@lists.debian.org) (gcc-10 (Debian 10.2.1-6) 10.2.1 20210110, GNU ld (GNU Bi>
  Nov 30 06:21:56 test-machine kernel: Command line: root=zfs:rpool/debian loglevel=4 spl.spl_hostid=0x00bab10c
  Nov 30 06:21:56 test-machine kernel: x86/fpu: Supporting XSAVE feature 0x001: 'x87 floating point registers'
  ...
  Nov 30 06:22:02 test-machine root[1193]: Swap was not activated at boot - attempting to activate it:  (from /usr/local/bin/checkswap.sh)
  ...
  Nov 30 06:22:02 test-machine root[1347]: mdraid device /dev/md0 has been activated  (from /usr/local/bin/checkswap.sh)
  ...
  Nov 30 06:22:02 test-machine root[1510]: Encrypted device /dev/dm-0 has been set up  (from /usr/local/bin/checkswap.sh)
  ...
  Nov 30 06:22:03 test-machine root[1524]: Swap was successfully activated  (from /usr/local/bin/checkswap.sh)
  Nov 30 06:22:03 test-machine systemd[1]: checkswap.service: Succeeded.
  Nov 30 06:22:03 test-machine systemd[1]: Finished Check swap and enable it if not active.

The mdraid array will then be running on a single drive (in this case sda3)::

  root@test-machine:/home/testuser# cat /proc/mdstat
  Personalities : [linear] [multipath] [raid0] [raid1] [raid6] [raid5] [raid4] [raid10]
  md0 : active raid1 sda3[0]
        67042304 blocks super 1.2 [2/1] [U_]

  unused devices: <none>

And swap will still be active::

  root@test-machine:/home/testuser# swapon -s
  Filename                                Type            Size    Used    Priority
  /dev/dm-0                               partition       67042300        0       -2

Once you have replaced the damaged disk, you will need to re-create the partitions that were on the failed disk by
following :ref:`partitioning-drives` above, copy your EFI boot image from the surviving EFI partiton to the replacement
disk EFI partition, ``zpool replace`` the replacement ZFS partition to the surviving ZFS partition, and then use
``mdadm`` to add the replacement swap partition to the mdraid array. In the case of the example failure shown above, the
command to add the new swap partition to the mdraid array would be::

  mdadm --manage /dev/md0 --add /dev/disk/by-partlabel/Swap-1-NVMe

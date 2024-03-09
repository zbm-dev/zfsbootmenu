Managing Redundant ESPs with mdraid
===================================

On a multi-device system, having multiple, redundant EFI system partitions may
be desirable. This can be achieved by using a :zbm:`post-generation hook <contrib/esp-sync.sh>`
to copy the generated ZFSBootMenu images between ESPs, but that requires generating
images yourself.

Using Linux's software RAID capabilities can allow for seamless and automatic ESP
redundancy, without requiring scripts to update each ESP.

1. Make an EFI System Partition on each disk::

    ESP_DISKS="/dev/sda /dev/sdb"
    for disk in $ESP_DISKS; do
        sgdisk -n "1:1m:+512m" -t "1:ef00" "$disk"
    done

2. Create the mdraid array::

    mdadm --create --verbose --level 1 --metadata 1.0 \
        --homehost any --raid-devices 2 /dev/md/esp \
        /dev/sda1 /dev/sdb1
    mdadm --assemble --scan
    mdadm --detail --scan >> /etc/mdadm.conf

.. note::

   Depending on the distribution, additional setup may be required to assemble the
   mdraid array on boot. Consult your distribution's documentation for more information.

3. Format the array as ``vfat``, create an fstab entry, and mount::

    mkfs.vfat -F32 /dev/md/esp

    cat << EOF >> /etc/fstab
    /dev/md/esp /boot/efi vfat defaults 0 0
    EOF

    mkdir -p /boot/efi
    mount /boot/efi

4. Install ZFSBootMenu in ``/boot/efi`` as desired.

If adding boot entries with ``efibootmgr``, add entries for each disk in the mdraid array.

.. note::

    This configuration exploits the fact that, with version 1.0, ``mdraid``
    metadata will be written to the *end* of each partition. Newer metadata
    versions would be written to the beginning of each partition, and the
    system firmware would fail to recognize each component as a valid EFI
    system partition.

    In general, allowing systems to directly access the constituent partitions
    of a Linux software RAID volume is inadvisable. However, the usual concerns
    about data integrity do not generally apply to mirroring of the EFI system
    partition. First, the firmware will generally read, but not write, the
    contents of these partitions; under normal circumstances, the only
    modifications made to the EFI system partitions will be by the Linux system
    that assembles them into an array. Second, if the firmware *does* commit
    any unintended writes to the partition from which it boots, inconsistencies
    can be reconciled with periodic resilvering in the host Linux installation.
    Finally, the contents of an EFI system partition are almost never critical.
    Unintended corruption of your EFI system partition could potentially
    prevent your system from booting, but the likelihood of such corruption is
    low and the partition can generally be trivially recovered in any event.

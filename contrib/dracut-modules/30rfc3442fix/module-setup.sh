#!/bin/bash
# Dracut module to install patched dhclient-script before the network-legacy module
# This module uses prefix 30 to load BEFORE 35network-legacy (which has the buggy version)

check() {
    return 0
}

depends() {
    return 0
}

install() {
    # Install our patched dhclient-script
    # Since we run before 35network-legacy, our version will be in place first
    # and dracut won't overwrite it
    if [ -f /sbin/dhclient-script ]; then
        inst_simple /sbin/dhclient-script /sbin/dhclient-script
    fi
}

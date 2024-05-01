#!/bin/bash

#
# Configure this script as a user teardown.d hook
#

SYS_MEGARAID=/sys/bus/pci/drivers/megaraid_sas

# shellcheck disable=SC2231
for DEVPATH in ${SYS_MEGARAID}/????:??:??.?; do
        [ -L "${DEVPATH}" ] || continue
        DEVICE="${DEVPATH#"${SYS_MEGARAID}"/}"
        echo "Tearing down Megaraid controller ${DEVICE}..."
        echo "${DEVICE}" > ${SYS_MEGARAID}/unbind
        echo "Resetting Megaraid controller ${DEVICE}..."
        echo "1" > /sys/bus/pci/devices/${DEVICE}/reset
done

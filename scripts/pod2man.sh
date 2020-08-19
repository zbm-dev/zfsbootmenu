#!/bin/sh

# Generate man pages from pod documentation

pod2man pod/generate-zbm.5.pod -c "config.yaml" \
  -r "${release}" -s 5 -n generate-zbm > man/generate-zbm.5

pod2man pod/zfsbootmenu.7.pod -c "ZFSBootMenu" \
  -r "${release}" -s 7 -n zfsbootmenu > man/zfsbootmenu.7

pod2man bin/generate-zbm -c "generate-zbm" \
  -r "${release}" -s 8 -n generate-zbm > man/generate-zbm.8

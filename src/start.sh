#!/bin/bash

set -o noclobber
(gunzip -c /app/distro.qcow2.gz > /dist/distro.qcow2) 2> /dev/null

cp -n /app/kernel8.img /dist
cp -n /app/pi3.dtb /dist

qemu-system-aarch64 \
  -M raspi3 \
  -m 1G \
  -smp 4 \
  -kernel /dist/kernel8.img \
  -dtb /dist/pi3.dtb \
  -sd /dist/distro.qcow2 \
  -nographic -no-reboot \
  -device usb-net,netdev=net0 -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -append "rw console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootdelay=1 loglevel=2 modules-load=dwc2,g_ether"

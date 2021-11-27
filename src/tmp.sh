#!/bin/bash

qemu-system-aarch64 \
   -M raspi3 \
   -m 1G \
   -smp 4 \
   -sd $BASE_DIR/$IMAGE_FILE_NAME \
   -kernel $BASE_DIR/$KERNEL_FILE_NAME \
   -dtb $BASE_DIR/$DTB_FILE_NAME \
   -nographic -no-reboot \
   -device usb-net,netdev=net0 -netdev user,id=net0,hostfwd=tcp::2222-:22 \
   -append "rw console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootdelay=1 loglevel=2 modules-load=dwc2,g_ether"
   
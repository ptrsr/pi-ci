#!/bin/bash

mkdir -p /project/dist
cp /build/distro.img /project/dist/distro.img
cp /build/linux/arch/arm64/boot/Image /project/dist/kernel8.img
cp /build/linux/arch/arm64/boot/dts/broadcom/bcm2710-rpi-3-b.dtb /project/dist/pi3.dtb

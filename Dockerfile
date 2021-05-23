FROM ubuntu:20.04 as builder

# RPI kernel source
ARG KERNEL_GIT=https://github.com/raspberrypi/linux.git
ARG KERNEL_BRANCH=rpi-5.4.y

# Kernel compile options
ARG KERNEL=kernel8
ARG ARCH=arm64
ARG CROSS_COMPILE=aarch64-linux-gnu-

# Install packages
ARG DEBIAN_FRONTEND="noninteractive"

RUN apt-get update \
 && apt install -y \
    bc \
    bison \
    crossbuild-essential-arm64 \
    flex \
    git \
    libssl-dev \
    libc6-dev \
    make

RUN git clone --single-branch --branch $KERNEL_BRANCH $KERNEL_GIT /linux/

COPY ./.config /linux/

ARG CORES=2
RUN make -C /linux/ -j$CORES Image modules dtbs

ENTRYPOINT ./tools/copy.sh

# RUN make -C /linux bcmrpi3_defconfig

# FROM ubuntu:20.04

# RUN echo "hello world!"

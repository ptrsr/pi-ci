# BIOMI-RPI
FROM debian:latest
# Global arguments
ARG DEBIAN_FRONTEND="noninteractive"

# Kernel source
ARG KERNEL_BRANCH=rpi-6.1.y

ARG BUILD_DIR=/build
ARG BASE_DIR=/base
ARG APP_DIR=/app
ARG IMAGE_FILE_NAME=raspios.qcow2
ARG IMAGE_FILE_NAME_COMPRESSED=$IMAGE_FILE_NAME.gz
ARG KERNEL_FILE_NAME=kernel.img

# Distro source
ARG DISTRO_DATE=2022-09-22
ARG DISTRO_NAME=bullseye
ARG DISTRO_TAG=$DISTRO_NAME-$DISTRO_DATE

# Qemu rpi emulation details
ARG MACHINE_TYPE=virt
ARG CPU_TYPE=cortex-a53
ARG CPU_NUMBER=4
ARG RAM_SIZE=512M

ARG RPI_SSH_PORT=2222

# Optimize APT for faster downloads
RUN echo 'Acquire::http::Pipeline-Depth "5";' > /etc/apt/apt.conf.d/99parallel \
    && echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/99languages \
    && echo 'path-exclude=/usr/share/doc/*\npath-exclude=/usr/share/man/*\npath-exclude=/usr/share/locale/*' > /etc/dpkg/dpkg.cfg.d/01_nodoc

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends  \
    python3 \
    python3-pip \
    qemu-system-aarch64 \
    qemu-efi-aarch64 \
    linux-image-generic \
    libguestfs-tools \
    libssl-dev \
    kmod \
    wget \
    openssl \
    xz-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/doc/* \
    && rm -rf /usr/share/man/* \
    && rm -rf /usr/share/locale/*

# Set environment variables
ENV PIP_BREAK_SYSTEM_PACKAGES=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DIST_DIR=/dist \
    STORAGE_PATH=/dev/mmcblk0 \
    PORT=$RPI_SSH_PORT \
    BASE_DIR=$BASE_DIR \
    APP_DIR=$APP_DIR \
    MACHINE_TYPE=$MACHINE_TYPE \
    CPU_TYPE=$CPU_TYPE \
    CPU_NUMBER=$CPU_NUMBER \
    RAM_SIZE=$RAM_SIZE \
    IMAGE_FILE_NAME=$IMAGE_FILE_NAME \
    KERNEL_FILE_NAME=$KERNEL_FILE_NAME

WORKDIR $DIST_DIR

# Copy application files
COPY src/app/ $APP_DIR/

# Install Python dependencies
RUN pip3 install --no-cache-dir -r $APP_DIR/requirements.txt

#==== Copy artifacts from previous stages to run the RPi tasks

# Get the kernel image
RUN wget https://github.com/PRISMProtocolHub/biomi-rpi-kernel-builder/releases/download/$KERNEL_BRANCH/kernel.img

# Get the raspios image
RUN wget https://github.com/PRISMProtocolHub/biomi-rpi-image-builder/releases/download/$DISTRO_TAG/raspios.qcow2.gz
RUN gunzip raspios.qcow2.gz

EXPOSE 2222

ENTRYPOINT ["/app/run.py"]
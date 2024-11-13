# PI-CI
# Global arguments
ARG DEBIAN_FRONTEND="noninteractive"
ARG BUILD_DIR=/build
ARG BASE_DIR=/base
ARG APP_DIR=/app
ARG IMAGE_FILE_NAME=distro.qcow2
ARG KERNEL_FILE_NAME=kernel.img

# Kernel source
ARG KERNEL_BRANCH=rpi-6.1.y
ARG KERNEL_GIT=https://github.com/raspberrypi/linux.git

# Distro source
ARG DISTRO_DATE=2022-09-22
ARG DISTRO_NAME=bullseye
ARG DISTRO_TAG=$DISTRO_NAME-$DISTRO_DATE

#========= Image building stage
# Create the raspberry OS image for SDCard using x86_64 platform that is faster
FROM ghcr.io/prismprotocolhub/biomi-rpi-image-builder:$DISTRO_TAG AS image-builder

# Kernel building stage
FROM ghcr.io/prismprotocolhub/biomi-rpi-kernel-builder:$KERNEL_BRANCH as kernel-builder

# Final stage
FROM debian:latest AS emulator

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
RUN apt-get update && apt-get install -y  \
    python3 \
    python3-pip \
    qemu-efi-aarch64 \
    linux-image-generic \
    libguestfs-tools \
    libssl-dev \
    kmod \
    wget \
    openssl \
    xz-utils \
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

# Install Python dependencies
COPY src/app/requirements.txt $APP_DIR/
RUN pip3 install --no-cache-dir -r $APP_DIR/requirements.txt

# Copy application files
COPY src/app/ $APP_DIR/

WORKDIR $BASE_DIR

# Copy artifacts from previous stages
COPY --from=image-builder $BUILD_DIR/$IMAGE_FILE_NAME $BASE_DIR/
COPY --from=kernel-builder $BUILD_DIR/$KERNEL_FILE_NAME $BASE_DIR/

ENTRYPOINT ["/app/run.py"]
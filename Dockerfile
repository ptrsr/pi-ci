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
ARG DISTRO_DATE_FOLDER=2022-09-26
ARG DISTRO_DATE=2022-09-22
ARG DISTRO_NAME=bullseye
ARG DISTRO_FILE=$DISTRO_DATE-raspios-$DISTRO_NAME-arm64-lite.img
ARG DISTRO_IMG=https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-$DISTRO_DATE_FOLDER/$DISTRO_FILE.xz

# Base Docker image for all the steps
FROM debian:latest AS base-deps
ARG DEBIAN_FRONTEND

# Optimize APT for faster downloads
RUN echo 'Acquire::http::Pipeline-Depth "5";' > /etc/apt/apt.conf.d/99parallel \
    && echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/99languages \
    && echo 'path-exclude=/usr/share/doc/*\npath-exclude=/usr/share/man/*\npath-exclude=/usr/share/locale/*' > /etc/dpkg/dpkg.cfg.d/01_nodoc

# Install common dependencies
RUN apt-get update && apt-get install -y  \
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

#========= Image building stage
# Create the raspberry OS image for SDCard using x86_64 platform that is faster
FROM base-deps AS image-builder
ARG BUILDPLATFORM
ARG BUILD_DIR
ARG DISTRO_FILE
ARG DISTRO_IMG

RUN apt-get update && apt-get install -y  \
    libguestfs-tools \
    libssl-dev \
    wget \
    openssl \
    linux-image-generic \
    xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/doc/* \
    && rm -rf /usr/share/man/* \
    && rm -rf /usr/share/locale/*

# Download and extract image
WORKDIR /tmp
RUN wget -nv -O $DISTRO_FILE.xz $DISTRO_IMG \
    && unxz $DISTRO_FILE.xz \
    && mkdir -p /mnt/root /mnt/boot

# Extract and modify system
RUN guestfish add $DISTRO_FILE : run : mount /dev/sda1 / : copy-out / /mnt/boot : umount / : mount /dev/sda2 / : copy-out / /mnt/root \
    && rm $DISTRO_FILE

# Copy configurations and modify system settings
COPY src/conf/fstab /mnt/root/etc/
COPY src/conf/cmdline.txt /mnt/boot/
COPY src/conf/99-qemu.rules /mnt/root/etc/udev/rules.d/
COPY src/conf/login.conf /mnt/root/etc/systemd/system/serial-getty@ttyAMA0.service.d/override.conf

RUN touch /mnt/boot/ssh \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /mnt/root/etc/ssh/sshd_config \
    && sed -i 's/#PermitEmptyPasswords no/permitEmptyPasswords yes/' /mnt/root/etc/ssh/sshd_config \
    && sed -i 's/^root:\*:/root::/' /mnt/root/etc/shadow \
    && sed -i '/^pi/d' /mnt/root/etc/{shadow,passwd,group} \
    && rm -r /mnt/root/home/pi \
    && mkdir -p /mnt/root/etc/systemd/system/serial-getty@ttyAMA0.service.d/ \
    && rm -f /mnt/root/usr/lib/systemd/system/userconfig.service \
    && rm -f /mnt/root/etc/systemd/system/multi-user.target.wants/userconfig.service

# Create final image
WORKDIR $BUILD_DIR
ARG DIST_IMAGE_PATH=$BUILD_DIR/distro.img

RUN guestfish -N $BUILD_DIR/distro.img=bootroot:vfat:ext4:2G \
    && guestfish add $BUILD_DIR/distro.img : run : mount /dev/sda1 / : glob copy-in /mnt/boot/* / : umount / : mount /dev/sda2 / : glob copy-in /mnt/root/* / \
    && sfdisk --part-type $BUILD_DIR/distro.img 1 c \
    && qemu-img convert -f raw -O qcow2 $BUILD_DIR/distro.img $BUILD_DIR/distro.qcow2 \
    && rm $BUILD_DIR/distro.img

# Kernel building stage
FROM base-deps AS kernel-builder
ARG BUILD_DIR
ARG KERNEL_GIT
ARG KERNEL_BRANCH

# Install kernel build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bc \
    gcc \
    bison \
    crossbuild-essential-arm64 \
    flex \
    git \
    make \
    && rm -rf /var/lib/apt/lists/*

WORKDIR $BUILD_DIR

# Set kernel build environment variables
ENV ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu-

# Clone and compile kernel
RUN git clone --depth 1 --single-branch --branch $KERNEL_BRANCH $KERNEL_GIT $BUILD_DIR/linux/ \
    && make -C $BUILD_DIR/linux defconfig kvm_guest.config \
    && make -C $BUILD_DIR/linux -j$(nproc) Image

COPY src/conf/custom.conf $BUILD_DIR/linux/kernel/configs/custom.config
RUN make -C $BUILD_DIR/linux custom.config \
    && make -C $BUILD_DIR/linux -j$(nproc) Image \
    && mv $BUILD_DIR/linux/arch/arm64/boot/Image $BUILD_DIR/kernel.img \
    && rm -rf $BUILD_DIR/linux

# Final stage
FROM base-deps AS emulator
ARG APP_DIR
ARG BASE_DIR

# Qemu rpi emulation details
ARG MACHINE_TYPE=virt
ARG CPU_TYPE=cortex-a53
ARG CPU_NUMBER=4
ARG RAM_SIZE=512M

ARG RPI_SSH_PORT=2222

# Install additional packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    qemu-efi-aarch64 \
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
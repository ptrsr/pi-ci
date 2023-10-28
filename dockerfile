# PI-CI
# Shared variables
ARG BUILD_DIR=/build/

FROM ubuntu:22.04 as builder

# Use shared build directory
ARG BUILD_DIR

# Kernel source
ARG KERNEL_GIT=https://github.com/raspberrypi/linux.git
ARG KERNEL_BRANCH=rpi-5.4.y

# Distro download
ARG DISTRO_FILE=2023-10-10-raspios-bookworm-arm64-lite.img
ARG DISTRO_IMG=https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2023-10-10/$DISTRO_FILE.xz

# Kernel compile options
ARG KERNEL=kernel8
ARG ARCH=arm64
ARG CROSS_COMPILE=aarch64-linux-gnu-

# Install dependencies
ARG DEBIAN_FRONTEND="noninteractive"
RUN apt-get update && apt install -y \
    bc \
    bison \
    crossbuild-essential-arm64 \
    flex \
    git \
    libc6-dev \
    libguestfs-tools \
    libssl-dev \
    linux-image-generic \
    make \
    wget \
    openssl \
    xz-utils

# Download raspbian distro
RUN wget -nv -O /tmp/$DISTRO_FILE.xz $DISTRO_IMG \
 && unxz /tmp/$DISTRO_FILE.xz

# Extract distro boot and root
RUN mkdir /mnt/root /mnt/boot \
 && guestfish add tmp/$DISTRO_FILE : run : mount /dev/sda1 / : copy-out / /mnt/boot : umount / : mount /dev/sda2 / : copy-out / /mnt/root

# Clone the RPI kernel repo
RUN git clone --single-branch --branch $KERNEL_BRANCH $KERNEL_GIT $BUILD_DIR/linux/

# Add WireGuard kernel module
RUN git clone https://git.zx2c4.com/wireguard-linux-compat $BUILD_DIR/wireguard-compat \
 && $BUILD_DIR/wireguard-compat/kernel-tree-scripts/jury-rig.sh $BUILD_DIR/linux/

# Copy build configuration
COPY src/conf/.config $BUILD_DIR/linux/
# Build kernel, modules and device tree blobs
RUN make -C $BUILD_DIR/linux/ -j$(nproc) Image modules dtbs

# Copy kernel, modules and device tree blobs to extracted distro
RUN cp $BUILD_DIR/linux/arch/arm64/boot/Image /mnt/boot/kernel8.img \
 && cp $BUILD_DIR/linux/arch/arm64/boot/dts/broadcom/*.dtb /mnt/boot/ \
 && cp $BUILD_DIR/linux/arch/arm64/boot/dts/overlays/*.dtb* /mnt/boot/overlays/ \
 && cp $BUILD_DIR/linux/arch/arm64/boot/dts/overlays/README /mnt/boot/overlays/ \
 && make -C $BUILD_DIR/linux/ INSTALL_MOD_PATH=/mnt/root modules_install

# Copy boot configuration
COPY src/conf/fstab /mnt/root/etc/
COPY src/conf/cmdline.txt /mnt/boot/
COPY src/conf/init_resize.sh /mnt/root/usr/lib/raspi-config/init_resize.sh

# Run SSH server on startup
RUN touch /mnt/boot/ssh

# Allow SSH root login with no password
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /mnt/root/etc/ssh/sshd_config \
 && sed -i 's/#PermitEmptyPasswords no/permitEmptyPasswords yes/' /mnt/root/etc/ssh/sshd_config

# Copy setup configuration
COPY src/conf/setup.service /mnt/root/usr/local/lib/systemd/system/
COPY src/conf/setup.sh /mnt/root/usr/local/bin/
RUN mkdir -p /mnt/root/usr/local/lib/systemd/system \
 && ln -rs /mnt/root/usr/local/lib/systemd/system/setup.service /mnt/root/etc/systemd/system/multi-user.target.wants \
 && ln -rs /mnt/root/lib/systemd/system/systemd-time-wait-sync.service /mnt/root/etc/systemd/system/sysinit.target.wants/systemd-time-wait-sync.service \
 && rm mnt/root/etc/systemd/system/timers.target.wants/apt-daily* \
 && ln -rs /mnt/root/dev/null /mnt/root/etc/systemd/system/serial-getty@ttyAMA0.service \
 && rm /mnt/root/etc/init.d/resize2fs_once

# Setup root auto login
RUN mkdir /mnt/root/etc/systemd/system/serial-getty@ttyAMA0.service.d/
COPY src/conf/login.conf /mnt/root/etc/systemd/system/serial-getty@ttyAMA0.service.d/override.conf

# Create new distro image from modified boot and root
RUN guestfish -N $BUILD_DIR/distro.img=bootroot:vfat:ext4:2G \
 && guestfish add $BUILD_DIR/distro.img : run : mount /dev/sda1 / : glob copy-in /mnt/boot/* / : umount / : mount /dev/sda2 / : glob copy-in /mnt/root/* / \
 && sfdisk --part-type $BUILD_DIR/distro.img 1 c
# Convert new distro image to sparse file
RUN qemu-img convert -f raw -O qcow2 $BUILD_DIR/distro.img $BUILD_DIR/distro.qcow2

CMD cp $BUILD_DIR/distro.qcow2 ./


# ---------------------------
FROM ubuntu:22.04 as emulator

# Project build directory
ARG BUILD_DIR
# Folder containing default configuration files
ENV BASE_DIR=/base/
# Folder containing helper scripts
ENV APP_DIR=/app/

ENV IMAGE_FILE_NAME=distro.qcow2
ENV KERNEL_FILE_NAME=kernel8.img
ENV DTB_FILE_NAME=pi3.dtb

# Copy build files
RUN mkdir $BASE_DIR
COPY --from=0 $BUILD_DIR/distro.qcow2 $BASE_DIR/$IMAGE_FILE_NAME
COPY --from=0 /mnt/boot/kernel8.img $BASE_DIR/$KERNEL_FILE_NAME
COPY --from=0 /mnt/boot/bcm2710-rpi-3-b.dtb $BASE_DIR/$DTB_FILE_NAME

# Install packages and build essentials
ARG DEBIAN_FRONTEND="noninteractive"
RUN apt-get update && apt install -y \
    python3 \
    python3-pip \
    qemu-system-arm \
    linux-image-generic \
    libguestfs-tools \
    qemu-efi

# Update system
RUN qemu-system-aarch64 \
   -M raspi3b \
   -m 1G \
   -smp 4 \
   -sd $BASE_DIR/$IMAGE_FILE_NAME \
   -kernel $BASE_DIR/$KERNEL_FILE_NAME \
   -dtb $BASE_DIR/$DTB_FILE_NAME \
   -nographic -no-reboot \
   -device usb-net,netdev=net0 -netdev user,id=net0 \
   -append "rw console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootdelay=1 loglevel=2 modules-load=dwc2,g_ether"

# Copy requirements first
COPY src/app/requirements.txt $APP_DIR/requirements.txt
# Install Python dependencies
RUN pip3 install -r $APP_DIR/requirements.txt

# Copy helper scripts
COPY src/app/ $APP_DIR

# Helper script on running container
ENTRYPOINT ["/app/run.py"]

# Helper variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV DIST_DIR /dist
ENV STORAGE_PATH /dev/mmcblk0
ENV PORT 2222

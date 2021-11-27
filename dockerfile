# PI-CI v0.2

# Shared variables
ARG BUILD_DIR=/build/

FROM ubuntu:20.04 as builder

# Use shared build directory
ARG BUILD_DIR

# Kernel source
ARG KERNEL_GIT=https://github.com/raspberrypi/linux.git
ARG KERNEL_BRANCH=rpi-5.4.y

# Distro download
ARG DISTRO_FILE=2021-05-07-raspios-buster-arm64-lite
ARG DISTRO_IMG=https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2021-05-28/$DISTRO_FILE.zip

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
    unzip \
    wget

# Download raspbian distro
RUN wget -nv -O /tmp/$DISTRO_FILE.zip $DISTRO_IMG \
 && unzip /tmp/$DISTRO_FILE.zip -d /tmp
# Extract distro boot and root
RUN mkdir /mnt/root /mnt/boot \
 && guestfish add tmp/$DISTRO_FILE.img : run : mount /dev/sda1 / : copy-out / /mnt/boot : umount / : mount /dev/sda2 / : copy-out / /mnt/root

# Clone the RPI kernel repo
RUN git clone --single-branch --branch $KERNEL_BRANCH $KERNEL_GIT $BUILD_DIR/linux/
# Copy build configuration
COPY src/.config $BUILD_DIR/linux/
# Build kernel, modules and device tree blobs
RUN make -C $BUILD_DIR/linux/ -j$(nproc) Image modules dtbs

# Copy kernel, modules and device tree blobs to extracted distro
RUN cp $BUILD_DIR/linux/arch/arm64/boot/Image /mnt/boot/kernel8.img \
 && cp $BUILD_DIR/linux/arch/arm64/boot/dts/broadcom/*.dtb /mnt/boot/ \
 && cp $BUILD_DIR/linux/arch/arm64/boot/dts/overlays/*.dtb* /mnt/boot/overlays/ \
 && cp $BUILD_DIR/linux/arch/arm64/boot/dts/overlays/README /mnt/boot/overlays/ \
 && make -C $BUILD_DIR/linux/ INSTALL_MOD_PATH=/mnt/root modules_install

# Copy boot configuration
COPY src/fstab /mnt/root/etc/
COPY src/cmdline.txt /mnt/boot/
# Run SSH server on startup
RUN touch /mnt/boot/ssh

# Copy setup configuration
RUN mkdir -p /mnt/root/usr/local/lib/systemd/system
COPY src/setup.service /mnt/root/usr/local/lib/systemd/system/
COPY src/setup.sh /mnt/root/usr/local/bin/
RUN ln -rs /mnt/root/usr/local/lib/systemd/system/setup.service /mnt/root/etc/systemd/system/multi-user.target.wants
RUN rm mnt/root/etc/systemd/system/timers.target.wants/apt-daily*

# Create new distro image from modified boot and root
RUN guestfish -N $BUILD_DIR/distro.img=bootroot:vfat:ext4:2G \
 && guestfish add $BUILD_DIR/distro.img : run : mount /dev/sda1 / : glob copy-in /mnt/boot/* / : umount / : mount /dev/sda2 / : glob copy-in /mnt/root/* / \
 && sfdisk --part-type $BUILD_DIR/distro.img 1 c
# Convert new distro image to sparse file
RUN qemu-img convert -f raw -O qcow2 $BUILD_DIR/distro.img $BUILD_DIR/distro.qcow2

CMD cp $BUILD_DIR/distro.qcow2 ./


# ---------------------------
FROM ubuntu:20.04 as emulator

ARG QEMU_GIT=https://github.com/qemu/qemu.git
ARG QEMU_BRANCH=v6.1.0-rc0

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
    build-essential \
    cmake \
    git \
    libglib2.0-dev \
    libgio-cil \
    libpixman-1-dev \
    ninja-build \
    pkg-config \
    python3.8 \
    python3-pip

# Set default Python version to 3.8 
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1

# Build and install Qemu from source
RUN git clone --single-branch --branch $QEMU_BRANCH $QEMU_GIT $BUILD_DIR/qemu/ \
 && mkdir $BUILD_DIR/qemu/build \
 && (cd $BUILD_DIR/qemu/build && ../configure --target-list=aarch64-softmmu) \
 && make -C $BUILD_DIR/qemu/build install -j$(nproc) \
 && rm -r $BUILD_DIR

# Update system and install Ansible
RUN qemu-system-aarch64 \
   -M raspi3 \
   -m 1G \
   -smp 4 \
   -sd $BASE_DIR/$IMAGE_FILE_NAME \
   -kernel $BASE_DIR/$KERNEL_FILE_NAME \
   -dtb $BASE_DIR/$DTB_FILE_NAME \
   -nographic -no-reboot \
   -device usb-net,netdev=net0 -netdev user,id=net0 \
   -append "rw root=/dev/mmcblk0p2 rootfstype=ext4 rootdelay=1 loglevel=2 modules-load=dwc2,g_ether" \
   2> /dev/null

# Copy requirements first
COPY src/app/requirements.txt $APP_DIR/requirements.txt
# Install Python dependencies
RUN pip3 install -r $APP_DIR/requirements.txt

# Remove redundant build dependencies
RUN apt-get purge --auto-remove -y \
    build-essential \
    cmake \
    git \
    libglib2.0-dev \
    ninja-build \
    pkg-config

# Copy helper scripts
COPY src/app/ $APP_DIR

# Helper script on running container
ENTRYPOINT ["/app/run.py"]

# Helper variables
ENV DIST_DIR /dist
ENV STORAGE_PATH /dev/mmcblk0
ENV PORT 2222

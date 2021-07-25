FROM ubuntu:20.04 as builder

# Project build directory
ARG BUILD_DIR=/build/

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
ARG BUILD_CORES=3

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
RUN make -C $BUILD_DIR/linux/ -j$BUILD_CORES Image modules dtbs

# Copy kernel, modules and device tree blobs to extracted distro
RUN cp $BUILD_DIR/linux/arch/arm64/boot/Image /mnt/boot/kernel8.img \
 && cp $BUILD_DIR/linux/arch/arm64/boot/dts/broadcom/*.dtb /mnt/boot/ \
 && cp $BUILD_DIR/linux/arch/arm64/boot/dts/overlays/*.dtb* /mnt/boot/overlays/ \
 && cp $BUILD_DIR/linux/arch/arm64/boot/dts/overlays/README /mnt/boot/overlays/ \
 && make -C $BUILD_DIR/linux/ INSTALL_MOD_PATH=/mnt/root modules_install

# Copy boot configuration
COPY src/fstab /mnt/root/etc/
COPY src/cmdline.txt /mnt/boot/
# Enable ssh server on startup
RUN touch /mnt/boot/ssh

# Create new distro image from modified boot and root
RUN guestfish -N $BUILD_DIR/distro.img=bootroot:vfat:ext4:2G \
 && guestfish add $BUILD_DIR/distro.img : run : mount /dev/sda1 / : glob copy-in /mnt/boot/* / : umount / : mount /dev/sda2 / : glob copy-in /mnt/root/* / \
 && sfdisk --part-type $BUILD_DIR/distro.img 1 c
# Convert new distro image to sparse file
RUN qemu-img convert -f raw -O qcow2 $BUILD_DIR/distro.img $BUILD_DIR/distro.qcow2

# Copy distro to current working directory for debugging
CMD cp $BUILD_DIR/distro.qcow2 ./


# ---------------------------
FROM ubuntu:20.04 as emulator

# Project build directory
ARG BUILD_DIR=/build/
ARG BUILD_CORES=3

ARG QEMU_GIT=https://github.com/qemu/qemu.git
ARG QEMU_BRANCH=v6.1.0-rc0

ARG RETRY_SCRIPT=https://raw.githubusercontent.com/kadwanev/retry/master/retry

# Copy build files
RUN mkdir /app/
COPY --from=0 /mnt/boot/bcm2710-rpi-3-b.dtb /app/pi3.dtb
COPY --from=0 $BUILD_DIR/distro.qcow2 /app/
COPY --from=0 /mnt/boot/kernel8.img /app/

# Install packages and build essentials
ARG DEBIAN_FRONTEND="noninteractive"
RUN apt-get update && apt install -y \
    build-essential \
    cmake \
    curl \
    git \
    libglib2.0-dev \
    libpixman-1-dev \
    ninja-build \
    pkg-config \
    python3.8 \
    ssh \
    sshpass

# Set default Python version to 3.8 
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1

# Install retry script
RUN curl $RETRY_SCRIPT -o /usr/local/bin/retry && chmod +x /usr/local/bin/retry

# Build and install Qemu from source
RUN git clone --single-branch --branch $QEMU_BRANCH $QEMU_GIT $BUILD_DIR/qemu/ \
 && mkdir $BUILD_DIR/qemu/build \
 && (cd $BUILD_DIR/qemu/build && ../configure --target-list=aarch64-softmmu) \
 && make -C $BUILD_DIR/qemu/build install -j$BUILD_CORES \
 && rm -r $BUILD_DIR
 
# Update system and install Ansible
RUN qemu-system-aarch64 \
   -M raspi3 \
   -m 1G \
   -smp 4 \
   -kernel /app/kernel8.img \
   -dtb /app/pi3.dtb \
   -sd /app/distro.qcow2 \
   -daemonize -no-reboot \
   -device usb-net,netdev=net0 -netdev user,id=net0,hostfwd=tcp::2222-:22 \
   -append "rw console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootdelay=1 loglevel=2 modules-load=dwc2,g_ether" \
 && retry 'sshpass -p raspberry ssh -o StrictHostKeyChecking=no -p 2222 pi@localhost "echo \"Machine ready\""' \
 && sshpass -p raspberry ssh -o StrictHostKeyChecking=no -p 2222 pi@localhost "\
    sudo apt-get update;\
    sudo apt-get install -y ansible;\
    sudo shutdown now;\
    " || true \
 && sleep 10

# Remove redundant build dependencies
RUN apt-get remove -y \
    build-essential \
    cmake \
    curl \
    git \
    libglib2.0-dev \
    libpixman-1-dev \
    ninja-build \
    pkg-config \
    python3.8 \
    sshpass

# Copy start script
COPY src/main /main

# Helper script on running container
ENTRYPOINT ["/main/run.py"]

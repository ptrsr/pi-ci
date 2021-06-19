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
ARG CORES=2

# Install dependencies
ARG DEBIAN_FRONTEND="noninteractive"
RUN apt-get update \
 && apt install -y \
    bc \
    bison \
    crossbuild-essential-arm64 \
    flex \
    git \
    gzip \
    libc6-dev \
    libguestfs-tools \
    libssl-dev \
    linux-image-generic \
    make \
    unzip \
    wget

# Provide predefined build configuration
COPY src/.config $BUILD_DIR

# Download distro and extract the distro's boot and root partitions
RUN wget -nv -O $BUILD_DIR/$DISTRO_FILE.zip $DISTRO_IMG \
 && unzip $BUILD_DIR/$DISTRO_FILE.zip -d $BUILD_DIR \
 && rm $BUILD_DIR/$DISTRO_FILE.zip \
 && mkdir /mnt/root /mnt/boot \
 && guestfish add $BUILD_DIR/$DISTRO_FILE.img : run : mount /dev/sda1 / : copy-out / /mnt/boot : umount / : mount /dev/sda2 / : copy-out / /mnt/root \
 && rm $BUILD_DIR/$DISTRO_FILE.img

# Clone the kernel source repo, build and copy the files to the distro
RUN git clone --single-branch --branch $KERNEL_BRANCH $KERNEL_GIT $BUILD_DIR/linux/ \
 && cp $BUILD_DIR/.config $BUILD_DIR/linux/ \
 && make -C $BUILD_DIR/linux/ -j$CORES Image modules dtbs \
 && rm -r /mnt/root/lib/modules/* \
 && rm /mnt/boot/*.dtb \
 && rm /mnt/boot/overlays/* \
 && rm /mnt/boot/kernel8.img \
 && cp $BUILD_DIR/linux/arch/arm64/boot/Image /mnt/boot/kernel8.img \
 && cp $BUILD_DIR/linux/arch/arm64/boot/dts/broadcom/*.dtb /mnt/boot/ \
 && cp $BUILD_DIR/linux/arch/arm64/boot/dts/overlays/*.dtb* /mnt/boot/overlays/ \
 && make -C $BUILD_DIR/linux/ INSTALL_MOD_PATH=/mnt/root modules_install \
 && rm -r $BUILD_DIR/linux/

# Use custom fstab
COPY src/fstab /mnt/root/etc/

# Enable ssh server on startup
RUN touch /mnt/boot/ssh

# Create sparse image from modified configuration and copy all build files to distribution folder
RUN mkdir $BUILD_DIR/dist \ 
 && guestfish -N $BUILD_DIR/distro.img=bootroot:vfat:ext4:2G \
 && guestfish add $BUILD_DIR/distro.img : run : mount /dev/sda1 / : glob copy-in /mnt/boot/* / : umount / : mount /dev/sda2 / : glob copy-in /mnt/root/* / \
 && qemu-img convert -f raw -O qcow2 $BUILD_DIR/distro.img $BUILD_DIR/dist/distro.qcow2 \
 && gzip $BUILD_DIR/dist/distro.qcow2 \
 && rm $BUILD_DIR/distro.img \
 && cp /mnt/boot/bcm2710-rpi-3-b.dtb $BUILD_DIR/dist/pi3.dtb \
 && cp /mnt/boot/kernel8.img $BUILD_DIR/dist

CMD cp $BUILD_DIR/dist ./

# ---------------------------
FROM ubuntu:20.04 as emulator

# Project build directory
ARG BUILD_DIR=/build/
ARG BUILD_CORES=2

ARG QEMU_GIT=https://github.com/qemu/qemu.git
ARG QEMU_BRANCH=v5.2.0

ARG RETRY_SCRIPT=https://raw.githubusercontent.com/kadwanev/retry/master/retry

# Copy build files
COPY --from=0 $BUILD_DIR/dist/ /app/

# Install packages and build essentials
ARG DEBIAN_FRONTEND="noninteractive"
RUN apt-get update && apt install -y \
    ansible \
    build-essential \
    cmake \
    curl \
    git \
    gzip \
    libglib2.0-dev \
    libpixman-1-dev \
    ninja-build \
    pkg-config \
    python3.8 \
    ssh \
    sshpass \
 && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1 \

 # Install retry script
 && curl $RETRY_SCRIPT -o /usr/local/bin/retry && chmod +x /usr/local/bin/retry \

 # Build and install Qemu from source
 && git clone --single-branch --branch $QEMU_BRANCH $QEMU_GIT $BUILD_DIR/qemu/ \
 && mkdir $BUILD_DIR/qemu/build \
 && (cd $BUILD_DIR/qemu/build && ../configure --target-list=aarch64-softmmu) \
 && make -C $BUILD_DIR/qemu/build install -j$BUILD_CORES \
 && rm -r $BUILD_DIR \

 # Unzip distro image 
 && gunzip /app/distro.qcow2.gz \

 # Start distro as daemon
 && qemu-system-aarch64 \
   -M raspi3 \
   -m 1G \
   -smp 4 \
   -kernel /app/kernel8.img \
   -dtb /app/pi3.dtb \
   -sd /app/distro.qcow2 \
   -daemonize -no-reboot \
   -device usb-net,netdev=net0 -netdev user,id=net0,hostfwd=tcp::2222-:22 \
   -append "rw console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootdelay=1 loglevel=2 modules-load=dwc2,g_ether" \
 # Update system and install ansible 
 && retry 'sshpass -p raspberry ssh -o StrictHostKeyChecking=no -p 2222 pi@localhost "echo \"Machine ready\""' \
 && sshpass -p raspberry ssh -o StrictHostKeyChecking=no -p 2222 pi@localhost "\
    sudo apt-get update;\
    sudo apt-get install -y ansible;\
    sudo shutdown now;\
    " || true \
 # Remove redundant build dependencies
 && apt-get remove -y \
    build-essential \
    cmake \
    curl \
    git \
    libglib2.0-dev \
    libpixman-1-dev \
    ninja-build \
    pkg-config \
    sshpass \
 # Stop the virtual machine
 && sleep 20 \
 && kill -15 $(pidof qemu-system-aarch64) \
 && sleep 10 \
# Finally compress the distro image
 && gzip /app/distro.qcow2

# Copy start script
COPY src/start.sh /

CMD ["/start.sh"]

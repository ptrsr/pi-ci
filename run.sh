#!/bin/bash
KERNEL_IMAGE_NAME="ptrsr/rpi-qemu-kernel"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)/"
DIST_DIR="$PROJECT_DIR/dist"

docker run --rm -it -v $DIST_DIR:/dist -w /dist $KERNEL_IMAGE_NAME

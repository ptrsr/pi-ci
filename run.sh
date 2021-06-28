#!/bin/bash
KERNEL_IMAGE_NAME="ptrsr/pi-ci"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)/"
DIST_DIR="$PROJECT_DIR/dist"

docker run --rm -it --network=host -v $DIST_DIR:/dist $KERNEL_IMAGE_NAME

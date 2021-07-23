#!/bin/bash
KERNEL_IMAGE_NAME="ptrsr/pi-ci"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)/../"
DIST_DIR="$PROJECT_DIR/dist"

docker run --rm -it -v $DIST_DIR:/dist --device=/dev/mmcblk0 $KERNEL_IMAGE_NAME "$@"

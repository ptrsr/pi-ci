#!/bin/bash
KERNEL_IMAGE_NAME="ptrsr/pi-ci"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)/../"

APP_DIR="$PROJECT_DIR/src/app"
DIST_DIR="$PROJECT_DIR/dist"

docker run --rm -it \
    -v $APP_DIR:/app \
    --device=/dev/mmcblk0 \
    --net=host \
    $KERNEL_IMAGE_NAME "$@"

    # --entrypoint=bash \
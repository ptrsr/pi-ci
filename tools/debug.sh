#!/bin/bash
KERNEL_IMAGE_NAME="ptrsr/pi-ci"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)/../"

APP_DIR="$PROJECT_DIR/src/app"
DIST_DIR="$PROJECT_DIR/dist"

docker run --rm -it \
    -v $DIST_DIR:/dist \
    -v $APP_DIR:/app \
    --net=host \
    $KERNEL_IMAGE_NAME "$@"

#!/bin/bash

KERNEL_IMAGE_NAME="ptrsr/pi-ci"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)/"

# Build Docker image
docker build -t $KERNEL_IMAGE_NAME:latest .

# Copies kernel files to the working directory
# docker run -it --rm \
#     -v $PROJECT_DIR:/project/ \
#     -w /project/ \
#     $KERNEL_IMAGE_NAME

#!/bin/bash

KERNEL_IMAGE_NAME="ptrsr/pi-ci"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)/../"

# Build Docker image
docker build -t $KERNEL_IMAGE_NAME:latest $PROJECT_DIR

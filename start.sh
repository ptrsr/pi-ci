#!/bin/bash
docker run --rm -it -v $(realpath .):/project -w /project ptrsr/rpi-qemu-kernel

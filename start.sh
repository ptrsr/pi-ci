#!/bin/bash
docker run --rm -it -v $(realpath .):/project ptrsr/rpi-qemu-kernel

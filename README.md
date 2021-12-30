# PI-CI [![PI-CI](https://github.com/ptrsr/pi-ci/actions/workflows/main.yml/badge.svg?branch=master)](https://github.com/ptrsr/pi-ci/actions/workflows/main.yml)
A raspberry Pi emulator in a [Docker image](https://hub.docker.com/r/ptrsr/pi-ci) that lets developers easily prepare and flash RPi configurations.

## Overview
The PI-CI project enables developers to easily:
- Run a RPi VM.
- Prepare a configuration inside a RPi VM.
- Flash a RPi VM image to a physical SD card.

Example use cases:
- Preconfigure Raspberry Pi servers that work from first boot.
- Create reproducible server configurations using Ansible.
- Automate the distribution of configurations through a CI pipeline.
- Test ARM applications in a virtualized environment.

Key features:
- Pi 3 and 4 support
- 64 bit (ARMv8) Raspberry PI OS (Buster) included
- Internet access
- No root required
- Ansible preinstalled
- Safe, fully reproducible from source
- Configurable kernel
- Tested and stable

## Usage
```sh
$ docker pull ptrsr/pi-ci
$ docker run --rm -it ptrsr/pi-ci

> usage: docker run [docker args] ptrsr/pi-ci [command] [optional args]
> 
> PI-CI: the reproducible PI emulator.
> 
> positional arguments:
>   command     [start, resize, flash]
> 
> optional arguments:
>   -h, --help  show this help message and exit
>   -v          show verbose output
> 
> Refer to https://github.com/ptrsr/pi-ci for the full README on how to use this program.
```
Each command has a help message, for example: 
`docker run --rm -it ptrsr/pi-ci start -h`.

### Start machine
Simply run a `ptrsr/pi-ci` container with the start command:
```sh
docker run --rm -it ptrsr/pi-ci start
```
Login using the default Raspbian credentials:
| Username | Password  | 
| -------- | --------- |
| pi       | raspberry | 

### Persistence
To save the resulting image, use a bind mount to `/dist`:
```sh
docker run --rm -it -v $PWD/dist:/dist ptrsr/pi-ci start
```
**NOTE**: this example will create and mount the `dist` folder in the current working directory of the host.

To restart the image, simply use the same bind mount.

### SSH access
To enable ssh access, run the image with the **host** network mode.
```sh
docker run --rm --network=host ptrsr/pi-ci start
```

Then ssh into the virtual Pi:
```sh
ssh pi@localhost -p 2222
```

## Resize
The default image is 2 gigabytes in size. This can be increased (but **not decreased!**) through the `resize` command. Increasing the size can be done in two ways:
1. by providing a path to the target device (e.g. `/dev/mmcblk0`). The resulting image will be the same size as the target device.

2. By providing a specific size in gigabytes, megabytes or bytes (e.g. 8G, 8192M, 8589934592).

For an image to be flashed to a device, the image has to be the less or equal to the device size.

**NOTE**: although an SD card will say a specific size (such as 16GB), the device is usually if not always smaller (GB vs GiB). Therefore, using a target device is recommended.

**NOTE**: resizing can potentially be a dangerous operation. Always make backup of the `image.qcow2` file in the `dist` folder before proceeding.

### Flash 
To flash the prepared image to a storage device (such as an SD card), provide the container with the device and run the flash command:
```sh
docker run --rm -it -v $PWD/dist:/dist --device=/dev/mmcblk0 ptrsr/pi-ci flash /dev/mmcblk0
```
On the first boot of the real RPi, a program will automatically inflate the root partition to fill the rest of the target device.

## Automation
Using Ansible, it is possible to automate the whole configuration process. Ansible requires docker-py to be installed. This can be done using `pip3 install docker-py'.

Ansible can take care of:
1. Starting the VM
2. Running tasks in the VM
3. Stopping the VM

An example configuration can be found in the `./test` folder of this repository. To start the test process, run:
```sh
ansible-playbook -i ./test/hosts.yml ./test/main.yml
```

## Tips
- Do not stop or kill the Docker container while the VM is running, this **WILL** corrupt the image!
- Make sure to regularly back up the `distro.qcow2` image.

## Versions
PI-CI should work on Ubuntu 18.04. It has automatically been tested on Ubuntu 20.04 using GitHub Actions. Any other distro should work with the following software versions (or higher, perhaps):

| Software  | Version  | 
| ----------| -------- |
| Ansible   | 2.5.1    |
| docker-py | 4.4.4    |
| Docker    | 19.03.6  |

## License
PI-CI is licensed under [GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html).

# PI-CI
[![PI-CI](https://github.com/ptrsr/pi-ci/actions/workflows/main.yml/badge.svg?branch=master)](https://github.com/ptrsr/pi-ci/actions/workflows/main.yml)

A [Docker image](https://hub.docker.com/repository/docker/ptrsr/pi-ci) for creating reproducible Raspberry Pi configurations using a virtual machine.

## Overview
The PI-CI project allows developers to easily prepare Raspberry Pi images on their computer or in the cloud. It provides a complete virtual machine in a docker container, which can be ran manually or automatically using Ansible. Some key features are:

- Pi 3 and 4 support
- 64 bit (ARMv8) Raspbian OS
- Internet access
- No root required
- Ansible preinstalled
- Fully reproducible and configurable
- Tested and stable

## Usage
### Manual
Simply pull the image and run a docker container for a simple test run:
```sh
docker pull ptrsr/pi-ci
docker run --rm -it ptrsr/pi-ci
```
Login using the default Raspbian credentials:
| Username | Password  | 
| -------- | --------- |
| pi       | raspberry | 

To enable internet access, run the image with the **host** network mode.
To make the configuration persistent, use a bind mount to `/dist`.
Complete example:
```sh
docker run --rm -it --network=host -v $(realpath .)/dist:/dist ptrsr/pi-ci
```
**NOTE**: this example will create and mount the `dist` folder in the current working directory of the host.

### Automatic
Using Ansible, it is possible to automate the whole configuration process. This includes:
1. Starting the VM
2. Running tasks in the VM
3. Stopping the VM

An example configuration can be found in the `./test` folder of this repository. To start the test process, run:
```sh
ansible-playbook -i ./test/hosts.yml ./test/main.yml
```

## Versions
PI-CI should work on Ubuntu 18.04. It has automatically been tested on Ubuntu 20.04 using GitHub Actions. Any other distro should work with the following software versions (or higher, perhaps):

| Software | Version  | 
| -------- | -------- |
| Ansible  | 2.5.1    |
| Docker   | 19.03.6  |

## License
PI-CI is licensed under [GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html).

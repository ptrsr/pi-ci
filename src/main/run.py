#!/bin/python3

# Import system libraries
import sys
import os
import argparse
import shutil
import socket
import subprocess

# Do not write pycache
sys.dont_write_bytecode=True

from lib.confirm import confirm
from lib.process import run
from lib.logger import log, logging

# Options from dict
class Options(object):
  def __init__(self, adict):
    self.__dict__.update(adict)


# Define help text
description = "PI-CI: the reproducible PI emulator."
epilog = "Refer to https://github.com/ptrsr/pi-ci for the full README on how to use this program."
usage = "docker run [docker args] ptrsr/pi-ci [optional args] [command]"


# Define command line arguments
parser = argparse.ArgumentParser(description=description, add_help=False, epilog=epilog, usage=usage, formatter_class=argparse.RawDescriptionHelpFormatter)
parser.add_argument('command', nargs='?', help="[start, status, resize, flash, backup]")
parser.add_argument('-n', dest='port', type=int, help="port number (default: 8000)", default=8000)
parser.add_argument('-s', dest='storage_dev', type=str, help="storage device (default: /dev/mmcblk0)", default='/dev/mmcblk0')
parser.add_argument('-d', dest='dist_path', type=str, help="storage path (default: /dist)", default='/dist')
parser.add_argument('-y', dest='confirm', action='store_false', help="skip confirmation", default=True)
parser.add_argument('-v', dest='verbose', action='store_true', help="verbose output", default=False)

args = Options(vars(parser.parse_args(sys.argv[1:])))


# Print help message
if args.command == None:
  parser.print_help()
  exit(0)

if args.verbose:
    log.setLevel(level=logging.DEBUG)
else:
    log.setLevel(level=logging.INFO)


# Checks
image_path = f'{args.dist_path}/distro.qcow2'
dtb_path = '/app/pi3.dtb'
kernel_path = '/app/kernel8.img'

has_volume = os.path.isdir(args.dist_path)
has_image = os.path.exists(image_path)
has_storage = os.path.exists(args.storage_dev)


# Status
if args.command == 'status':
  def print_status(title, message):
    print(f"[{title}] {message}")

  try:
    socket.create_connection(("1.1.1.1", 53))
    print_status("INTERNET", "Online")
  except:
    print_status("INTERNET", "Offline")

  if not has_volume:
    print_status("PERSISTENCE", "No, missing volume")
  else:
    if has_image:
      print_status("PERSISTENCE", "Yes, image found")
    else:
      print_status("PERSISTENCE", "Yes, image will be created on start")
  
  if has_storage:
    print_status("STORAGE", "Yes, storage found")
  else:
    print_status("STORAGE", "No, missing storage")

  exit(0)


# Start
if args.command == 'start':
  if has_volume:
    if not has_image:
      log.info("No previous image found, creating a new one ...")
      shutil.copyfile('/app/distro.qcow2', image_path)
    else:
      log.debug("Using existing image ...")
  else:
    image_path = '/app/distro.qcow2'

  # TODO: copy kernel / dtb to persistence?

  log.info("Starting the emulator ...")
  subprocess.Popen(f"""
    qemu-system-aarch64 \
    -M raspi3 \
    -m 1G \
    -smp 4 \
    -kernel {kernel_path} \
    -dtb {dtb_path} \
    -sd {image_path} \
    -nographic -no-reboot \
    -device usb-net,netdev=net0 -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -append \"rw console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootdelay=1 loglevel=2 modules-load=dwc2,g_ether\"
  """, shell=True).wait()
  exit(0)


if args.command == 'resize':
  run('qemu-img resize /dist/distro.qcow2 4G')
  exit(0)


if args.command == 'flash':
  if not has_image:
    log.error("No image found!")
    exit(1)

  if args.confirm:  
    if not confirm("Flashing will overide any data on the storage device. Continue?", None):
      exit(0)

  log.info("Converting image ...")
  run('qemu-img convert -p -f qcow2 -O raw /dist/distro.qcow2 /tmp/distro.img')
  log.info("Flashing image to drive ...")
  run('dd bs=4M if=/tmp/distro.img of=/dev/mmcblk0 status=progress')
  exit(0)


if args.command == 'backup':
  if has_image:
    if not confirm("An image already exists in the dist folder. Do you want to overwrite?", default='no'):
      print("Please move the distro.img file in the dist folder.")
      exit(0)
    else:
      log.inf("Removing old image ...")
      os.remove(image_path)
    
  log.info("Copying image from drive ...")
  run('dd conv=sparse bs=4M if=/dev/mmcblk0 of=/tmp/distro.img status=progress')
  log.info("Converting image ...")
  run('qemu-img convert -p -f raw -O qcow2 /tmp/distro.img /dist/distro.qcow2')
  exit(0)

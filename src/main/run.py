#!/bin/python3

# Import system libraries
import sys
import os
import argparse
import gzip
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
parser.add_argument('command', nargs='?', help="[start, status, flash, backup]")
parser.add_argument('-n', dest='port', type=int, help="port number", default=8000)
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
has_volume = os.path.isdir('/dist')
has_image = os.path.exists('/dist/distro.qcow2')
has_storage = os.path.exists('/dev/mmcblk0')
# Status
if args.command == 'status':
  def print_status(title, message):
    print(f"[{title}]: {message}")

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
      print_status("PERSISTENCE", "yes, image will be created on start")
  
  if has_storage:
    print_status("STORAGE", "Yes, storage found")
  else:
    print_status("STORAGE", "No, missing storage")

  exit(0)

# Start
if args.command == 'start':
  image_path = '/dist/distro.qcow2' if has_volume else '/tmp/distro.qcow2'

  if not has_image:
    log.info("No previous image found, creating a new one...")
    with gzip.open('/app/distro.qcow2.gz', 'rb') as f_in:
      with open(image_path, 'wb') as f_out:
          shutil.copyfileobj(f_in, f_out)

  if has_volume:
    log.info("No kernel found, using default one...")
    if not os.path.exists('/dist/kernel8.img'):
      shutil.copyfile('/app/kernel8.img', '/dist/kernel8.img')

    if not os.path.exists('/dist/pi3.dtb'):
      log.info("No device tree blob found, using default one...")
      shutil.copyfile('/app/pi3.dtb', '/dist/pi3.dtb')

  log.info("Starting the emulator...")
  # Run Qemu and attach shell
  subprocess.Popen("""
    qemu-system-aarch64 \
    -M raspi3 \
    -m 1G \
    -smp 4 \
    -kernel /dist/kernel8.img \
    -dtb /dist/pi3.dtb \
    -sd /dist/distro.qcow2 \
    -nographic -no-reboot \
    -device usb-net,netdev=net0 -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -append \"rw console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootdelay=1 loglevel=2 modules-load=dwc2,g_ether\"
  """, shell=True).wait()

if args.command == 'backup':
  if has_image:
    if not confirm("An image already exists in the dist folder. Do you want to overwrite?", default='no'):
      print("Please move the distro.img file in the dist folder.")
      exit(0)
    
  log.info("Copying image from drive...")
  run('dd bs=4M if=/dev/mmcblk0 of=/tmp/distro.img status=progress')
  log.info("Converting image...")
  run('qemu-img convert -p -f raw -O qcow2 /tmp/distro.img /dist/distro.qcow2')

if args.command == 'flash':
  if not has_image:
    log.error("No image found!")
    exit(0)

  log.info("Converting image...")
  run('qemu-img convert -p -f qcow2 -O raw /dist/distro.qcow2 /tmp/distro.img')
  log.info("Flashing image to drive...")
  run('dd bs=4M if=/tmp/distro.img of=/dev/mmcblk0 status=progress')


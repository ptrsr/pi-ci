import os, shutil, subprocess
from lib.logger import log
from lib.process import run

def check_base_file(file_name, base_dir, dist_dir):
    has_file = os.path.isfile(f'{dist_dir}/{file_name}')
    if not has_file:
      # Copy base file to shared volume
      log.info(f"No '{file_name}' provided in volume, providing default one ...")
      shutil.copyfile(f'{base_dir}/{file_name}', f'{dist_dir}/{file_name}')


def start(opts):
  # Check if (Docker) volume folder exists
  has_volume = os.path.isdir(opts.DIST_DIR)

  if not has_volume:
    # Start temporary session
    log.warn(f"No volume provided at '{opts.DIST_DIR}'!")
    log.warn("Starting emulator without persistence ...")
  else:
    # Ensure that all base files are shared
    log.debug(f"Volume '{opts.DIST_DIR}' exists ...")

    base_files = [ 
      opts.IMAGE_FILE_NAME,
      opts.KERNEL_FILE_NAME,
      opts.DTB_FILE_NAME 
    ]
    
    # Check and resolve required files for running emulator
    for file in base_files:
      check_base_file(file, opts.BASE_DIR, opts.DIST_DIR)

  # Define paths to emulator files
  run_dir = opts.DIST_DIR if has_volume else opts.BASE_DIR
  image_path = f'{run_dir}/{opts.IMAGE_FILE_NAME}'
  kernel_path = f'{run_dir}/{opts.KERNEL_FILE_NAME}'
  dtb_path = f'{run_dir}/{opts.DTB_FILE_NAME}'

  # Start emulator
  log.info("Starting the emulator ...")
  run(f"""
    qemu-system-aarch64 \
    -M raspi3 \
    -m 1G \
    -smp 4 \
    -sd {image_path} \
    -kernel {kernel_path} \
    -dtb {dtb_path} \
    -nographic -no-reboot \
    -device usb-net,netdev=net0 -netdev user,id=net0,hostfwd=tcp::{opts.port}-:22 \
    -append \"rw console=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootdelay=1 loglevel=2 modules-load=dwc2,g_ether\"
    """,
    get_output=False,
    stderr=None if opts.verbose else subprocess.DEVNULL
  )


# Start command parser
def start_parser(parsers, parent_parser, get_usage, env):
    description = "Command for starting the emulator."

    parser = parsers.add_parser("start", description=description, parents=[parent_parser], usage=get_usage('start'))
    parser.add_argument('-p', dest='port', type=int, help=f"port number (default: {env.PORT})", default=env.PORT)

    parser.set_defaults(func=lambda *args: start(*args))

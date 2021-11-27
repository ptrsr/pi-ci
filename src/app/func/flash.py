import os

from lib.logger import log
from lib.confirm import confirm
from lib.process import run


def flash(opts):
  has_image = os.path.isfile(f'{opts.DIST_DIR}/{opts.IMAGE_FILE_NAME}')

  if not has_image:
    log.error("No image found!")
    exit(1)

  if opts.confirm:  
    if not confirm("Flashing will overide any data on the storage device. Continue?", None):
      exit(0)

  log.info("Converting image ...")
  run(f'qemu-img convert -p -f qcow2 -O raw {opts.DIST_DIR}/{opts.IMAGE_FILE_NAME} /tmp/{opts.IMAGE_FILE_NAME}')
  log.info("Flashing image to drive ...")
  run(f'dd bs=4M if=/tmp/{opts.IMAGE_FILE_NAME} of={opts.storage_path} status=progress')


# Flash command parser
def flash_parser(parsers, parent_parser, get_usage, env):
    description = "Command for flashing the image to an SD card"

    parser = parsers.add_parser('flash', description=description, parents=[parent_parser], usage=get_usage('flash'), add_help=False)
    parser.add_argument('-s', dest='storage_path', type=str, help=f"storage device (default: {env.STORAGE_PATH})", default=env.STORAGE_PATH)
    parser.add_argument('-y', dest='confirm', action='store_false', help="skip confirmation", default=True)

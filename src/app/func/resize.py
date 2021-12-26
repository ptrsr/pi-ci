import os, re, subprocess
from lib.logger import log
from lib.confirm import confirm
from lib.image import get_device_size, get_image_size, get_virtual_size
from func.start import check_base_file


GB_TO_BYTE = 1073741824


def resize(opts):
  # TODO: confirm
  # TODO: show size

  # Check if (Docker) volume folder exists
  has_volume = os.path.isdir(opts.DIST_DIR)

  if not has_volume:
    # Start temporary session
    log.error(f"No volume provided at '{opts.DIST_DIR}'!")
    exit(1)

  check_base_file(opts.IMAGE_FILE_NAME, opts.BASE_DIR, opts.DIST_DIR)

  # Find last sector of virtual image
  log.info("Checking current image size ...")
  virtual_image_size = get_image_size(opts.IMAGE_FILE_PATH)


  if virtual_image_size == opts.target:
    log.info("Virtual image already correct size!")
    exit(0)
  elif virtual_image_size > opts.target:
    log.error("Virtual image size is larger than target!")
    exit(1)

  virtual_device_size = get_virtual_size(opts.IMAGE_FILE_PATH)

  # Size of virtual image in GB
  desired_device_size = None
  for i in [ 4, 8, 16, 32, 64, 128, 256 ]:
    if i * GB_TO_BYTE > opts.target:
      desired_device_size = i * GB_TO_BYTE
      break

  if virtual_device_size > desired_device_size:
    # NOTE: this may be possible/fine, but exit for now
    log.error("Current virtual image size is larger than desired size!")
    exit(1)
  elif virtual_device_size == desired_device_size:
    log.debug("Virtual image already is correct size")
  else:
    log.info("Resizing virtual image ...")
    # TODO: check status
    subprocess.getoutput(f'qemu-img resize {opts.IMAGE_FILE_PATH} {desired_device_size}')

  log.info("Resizing virtual partition ...")
  end_sector = int(opts.target / 512)
  # TODO: check status
  subprocess.getoutput(f"""guestfish add {opts.IMAGE_FILE_PATH} : run \
    : part-resize /dev/sda 2 {end_sector} \
    : resize2fs /dev/sda2
    """)

  log.info("Resize successful")


def parse_size(input: str):
    return int(input) if input.isnumeric() else get_device_size(input)


# Start command parser
def resize_parser(parsers, parent_parser, get_usage, env):
  description = "command for resizing the image."

  parser = parsers.add_parser('resize', description=description, usage=get_usage('resize'))

  parser.add_argument('target', type=parse_size, help="Target size in bytes, or path to target device")
  parser.add_argument('-d', dest='dist_path', type=str, help="storage path (default: /dist)", default='/dist')
  parser.add_argument('-y', dest='confirm', action='store_false', help="skip confirmation", default=True)

  parser.set_defaults(func=lambda *args: resize(*args))

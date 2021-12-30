import os, re, argparse, textwrap

from lib.logger import log
from lib.confirm import confirm
from lib.process import run
from lib.image import get_device_size, get_image_size, get_virtual_size, Size
from func.start import check_base_file


def resize(opts):
  # Check if (Docker) volume folder exists
  has_volume = os.path.isdir(opts.DIST_DIR)

  if not has_volume:
    raise FileNotFoundError(f"No volume provided at '{opts.DIST_DIR}'!")

  check_base_file(opts.IMAGE_FILE_NAME, opts.BASE_DIR, opts.DIST_DIR)

  if opts.confirm and not confirm("Resizing can damage the image, make sure to make a backup. Continue?", None):  
    exit(0)

  log.info(f"Resizing to {opts.target} bytes ...")

  # Find last sector of virtual image
  log.info("Checking current image size ...")
  virtual_image_size = get_image_size(opts.IMAGE_FILE_PATH)

  if virtual_image_size == opts.target:
    log.info("Image is already correct size!")
    log.info("Exiting ...")
    exit(0)
  elif virtual_image_size > opts.target:
    raise RuntimeError("Virtual image size is larger than target!")

  virtual_device_size = get_virtual_size(opts.IMAGE_FILE_PATH)

  # Size of virtual image in GB
  desired_device_size = None
  for i in [ 4, 8, 16, 32, 64, 128, 256 ]:
    if i * Size.GIGABYTE > opts.target:
      desired_device_size = i * Size.GIGABYTE
      break

  if virtual_device_size > desired_device_size:
    # NOTE: this may be possible/fine, but exit for now
    raise RuntimeError("Current virtual image size is larger than desired size!")
  elif virtual_device_size == desired_device_size:
    log.debug("Virtual image already is correct size")
  else:
    log.info("Resizing virtual image ...")
    # TODO: check status
    run(f'qemu-img resize {opts.IMAGE_FILE_PATH} {desired_device_size}', True)

  log.info("Resizing virtual partition ...")
  end_sector = int(opts.target / Size.BLOCK)

  run(f"""guestfish add {opts.IMAGE_FILE_PATH} : run \
    : part-resize /dev/sda 2 {end_sector} \
    : resize2fs /dev/sda2
    """,
    True
  )

  log.info("Resize successful")


def parse_size(input: str) -> int:
  if os.path.exists(input):
    return get_device_size(input)

  try:
    (size, unit) = re.search('^(\d+)([a-z,A-Z])?$', input).group(1, 2)
  except:
    raise RuntimeError("Invalid target device or size. For help, run PI-CI with 'resize -h'.")

  if unit == None:
    return int(size)
  elif unit.lower() == 'm':
    return int(size) * Size.MEGABYTE
  elif unit.lower() == 'g':
    return int(size) * Size.GIGABYTE

  raise RuntimeError("Invalid target size. Either provide number in bytes, megabyte (e.g. 8192M) or gigabyte (e.g. 8G).")


# Start command parser
def resize_parser(parsers, parent_parser, get_usage, env):
  description = "Command for resizing the virtual image."
  usage = f"{get_usage('resize')} [target]"

  help = textwrap.dedent("""\
    Target size OR path to target device.

    Target device (e.g. /dev/mmcblk0):
      resizes the image to match the device size.
    
    Target size (e.g. 8G, 8192M, 8589934592):
      resizes image to specific amount of GB, MB or bytes.
  """)

  parser = parsers.add_parser('resize', formatter_class=argparse.RawTextHelpFormatter, description=description, parents=[parent_parser], usage=usage)

  parser.add_argument('target', type=parse_size, help=help)
  parser.add_argument('-y', dest='confirm', action='store_false', help="skip confirmation", default=True)

  parser.set_defaults(func=lambda *args: resize(*args))

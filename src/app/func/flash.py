import os, re, shutil
from lib.logger import log
from lib.image import get_device_size, get_image_size
from lib.confirm import confirm
from lib.process import run


def flash(opts):
  has_image = os.path.isfile(opts.IMAGE_FILE_PATH)

  if not has_image:
    raise FileNotFoundError("No image found!")

  if opts.confirm and not confirm("Flashing will overide any data on the storage device. Continue?", None):  
    exit(0)

  log.info("Checking device and image ...")
  image_size = get_image_size(opts.IMAGE_FILE_PATH)
  device_size = get_device_size(opts.target)

  if image_size > device_size:
    raise RuntimeError("Image size is larger than device size!")

  tmp_path = f'/tmp/{opts.IMAGE_FILE_NAME}'

  log.info("Creating temporary copy of image ...")
  shutil.copyfile(opts.IMAGE_FILE_PATH, tmp_path)

  log.info("Minimizing temporary image ...")

  partition_info = run(f"""guestfish add {tmp_path} : run \
    : resize2fs-M /dev/sda2 \
    : tune2fs-l /dev/sda2
    """,
    True
  )

  filesystem_blocks = int(re.search('Block count: (\d+)', partition_info).group(1))
  filesystem_block_size = int(re.search('Block size: (\d+)', partition_info).group(1))

  filesystem_size = filesystem_blocks * filesystem_block_size

  partition_list = run(f'guestfish add {tmp_path} : run : part-list /dev/sda', True)
  partition_start = int(re.findall('part_start: (\d+)', partition_list)[1])

  desired_partition_end = partition_start + filesystem_size

  log.info("Flashing image to target ...")
  run(f'virt-resize -f qcow2 -o raw --resize-force /dev/sda2={desired_partition_end}b --no-extra-partition {tmp_path} {opts.target}', True)
  log.info("Flash successful")


# Flash command parser
def flash_parser(parsers, parent_parser, get_usage, env):
    description = "Command for flashing the image to an SD card"

    parser = parsers.add_parser('flash', description=description, parents=[parent_parser], usage=get_usage('flash'), add_help=False)
    parser.add_argument('target', type=str, help=f"storage device (default: {env.STORAGE_PATH})", default=env.STORAGE_PATH)
    parser.add_argument('-y', dest='confirm', action='store_false', help="skip confirmation", default=True)

    parser.set_defaults(func=lambda *args: flash(*args))

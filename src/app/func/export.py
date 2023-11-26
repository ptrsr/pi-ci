import os
from lib.logger import log
from lib.confirm import confirm
from lib.process import run
from lib.image import get_partition_size

def shrink(image_path: str, confirmed: bool = False):
  if confirmed and not confirm("Shrinking can damage the image, make sure to make a backup. Continue?", None):  
    exit(0)

  log.info("shrink the image ...")
  device_size = get_partition_size(image_path)
  log.debug(f"device size: {device_size}")
  run(f'qemu-img resize --shrink {image_path} {device_size}')
  log.info("shrink successful")


def export(opts):
  # Check if (Docker) volume folder exists
  has_volume = os.path.isdir(opts.DIST_DIR)

  if not has_volume and not confirm("The shared volume has not been mounted, do you want to continue exporting?", 'yes'):  
    exit(0)

  if (opts.shrink):
    shrink(opts.input)

  log.info("exporting the image ...")
  run(f'qemu-img convert -f qcow2 -O raw {opts.input} {opts.output}')
  log.info("Export successful")


# Flash command parser
def export_parser(parsers, parent_parser, get_usage, env):
  description = "Command for exporting the virtual qcow image to a raw image"
  file_input = f"{env.DIST_DIR}/{env.IMAGE_FILE_NAME}"
  file_output = f"{env.DIST_DIR}/export.img"

  parser = parsers.add_parser('export', description=description, parents=[parent_parser], usage=get_usage('export'))
  parser.add_argument('-s', '--shrink', action='store_true', help="shrink the image to the size of the underlying partitions", default=False, required=False)
  parser.add_argument('-i', '--input', type=str, help=f"input file (default: {file_input})", default=file_input, required=False)
  parser.add_argument('-o', '--output', type=str, help=f"output file (default: {file_output})", default=file_output, required=False)
  parser.add_argument('-y', dest='confirmed', action='store_false', help="skip confirmation", default=True)

  parser.set_defaults(func=lambda *args: export(*args))

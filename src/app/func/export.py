import os, re, shutil
from lib.logger import log
from lib.confirm import confirm
from lib.process import run


def export(opts):
  # Check if (Docker) volume folder exists
  has_volume = os.path.isdir(opts.DIST_DIR)

  if not has_volume and not confirm("The shared volume has not been mounted, do you want to continue exporting?", 'yes'):  
    exit(0)

  log.info("exporting the image ...")
  run(f'qemu-img convert -f qcow2 -O raw {opts.input} {opts.output}')
  log.info("Export successful")


# Flash command parser
def export_parser(parsers, parent_parser, get_usage, env):
  description = "Command for exporting the virtual qcow image to a raw image"
  file_input = f"{env.DIST_DIR}/{env.IMAGE_FILE_NAME}"
  file_output = f"{env.DIST_DIR}/export.img"

  parser = parsers.add_parser('export', description=description, parents=[parent_parser], usage=get_usage('export'))
  parser.add_argument('-i', '--input', type=str, help=f"input file (default: {file_input})", default=file_input, required=False)
  parser.add_argument('-o', '--output', type=str, help=f"output file (default: {file_output})", default=file_output, required=False)

  parser.set_defaults(func=lambda *args: export(*args))

import os, shutil, subprocess
from lib.logger import log
from lib.process import run


def check_base_file(file_name, base_dir, dist_dir):
  file_exists = os.path.exists(f'{dist_dir}/{file_name}')
  if not file_exists:
    # Copy base file to shared volume
    log.info(f"No '{file_name}' provided in volume, providing default one ...")
    if os.path.isfile(f'{base_dir}/{file_name}'):
      shutil.copyfile(f'{base_dir}/{file_name}', f'{dist_dir}/{file_name}')
    if os.path.isdir(f'{base_dir}/{file_name}'):
      shutil.copytree(f'{base_dir}/{file_name}', f'{dist_dir}/{file_name}', symlinks=False, ignore_dangling_symlinks=True)
  else:
    log.info(f"'{file_name}' already exists ...")


def start(opts):
  # Check if (Docker) volume folder exists
  has_volume = os.path.isdir(opts.dist)

  if not has_volume:
    # Start temporary session
    log.error(f"No volume provided at '{opts.dist}'!")
    exit(1)
    log.warn("Starting emulator without persistence ...")
  else:
    # Ensure that all base files are shared
    log.debug(f"Volume '{opts.dist}' exists ...")

    base_files = [ 
      opts.IMAGE_FILE_NAME,
      opts.KERNEL_FILE_NAME,
      'lib/modules/'
    ]
    
    # Check and resolve required files for running emulator
    for file in base_files:
      check_base_file(file, opts.BASE_DIR, opts.DIST_DIR)


# init command parser
def init_parser(parsers, parent_parser, get_usage, env):
  description = "Command for initializing base files for the emulator in the chosen distribution folder."

  parser = parsers.add_parser("init", description=description, parents=[parent_parser], usage=get_usage('init'))
  parser.add_argument('-d', '--dist', dest='dist', type=str, help=f"folder in which to initialize (default: {env.DIST_DIR})", default=env.DIST_DIR)

  parser.set_defaults(func=lambda *args: start(*args))

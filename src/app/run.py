#!/bin/python3

# Import system libraries
import sys, argparse

from lib.config import get_env
from lib.logger import log, logging

from func.start import start_parser
from func.resize import resize_parser
from func.flash import flash_parser

# Use environment variables (defaults given in dockerfile)
env = get_env()

# Help text
usage = "docker run [docker args] ptrsr/pi-ci"
get_usage = lambda command: f"{usage} {command} [optional args]"

main_usage = f"{usage} [command] [optional args]"
main_description = "PI-CI: the reproducible PI emulator."
main_epilog = "Refer to https://github.com/ptrsr/pi-ci for the full README on how to use this program."

# Parser arguments that are shared between subparsers
shared_parser = argparse.ArgumentParser(add_help=False)
shared_parser.add_argument('-v', dest='verbose', action='store_true', help="show verbose output", default=False)

# Main CLI parser
parser = argparse.ArgumentParser(description=main_description, epilog=main_epilog, usage=main_usage, parents=[shared_parser])

# Define CLI subcommand group
command_group = parser.add_subparsers(metavar="command", help="[start, resize, flash]")

# Define CLI subcommands
for enable_parser in [start_parser, resize_parser, flash_parser]:
  enable_parser(command_group, shared_parser, get_usage, env)

# Get CLI arguments
try:
  args = parser.parse_args(sys.argv[1:])
except Exception as e:
  log.error(e)
  log.info("Exiting ...")
  exit(1)

# Print help on missing command or help argument
if not 'func' in args:
  parser.print_help()
  exit(0)

# Combine arguments and variables into options
opts = argparse.Namespace(**vars(args), **vars(env))
opts.IMAGE_FILE_PATH = f'{opts.DIST_DIR}/{opts.IMAGE_FILE_NAME}'

# Set verbose logging
if args.verbose:
  log.setLevel(level=logging.DEBUG)
else:
  log.setLevel(level=logging.INFO)

# Run command function using options
try:
  args.func(opts)
except Exception as e:
  log.error(e)
  log.info("Exiting ...")
  exit(1)

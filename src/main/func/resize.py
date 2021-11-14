
# def resize(opts):
#   run('qemu-img resize /dist/distro.qcow2 4G')
#   exit(0)


# if args.command == 'flash':
#   if not has_image:
#     log.error("No image found!")
#     exit(1)

#   if args.confirm:  
#     if not confirm("Flashing will overide any data on the storage device. Continue?", None):
#       exit(0)

#   log.info("Converting image ...")
#   run('qemu-img convert -p -f qcow2 -O raw /dist/distro.qcow2 /tmp/distro.img')
#   log.info("Flashing image to drive ...")
#   run('dd bs=4M if=/tmp/distro.img of=/dev/mmcblk0 status=progress')
#   exit(0)

# Start command parser
def resize_parser(parsers, parent_parser, get_usage, env):
    description = "command for resizing the image"

    parser = parsers.add_parser('resize', description=description, usage=get_usage('resize'))
    parser.add_argument('-d', dest='dist_path', type=str, help="storage path (default: /dist)", default='/dist')
    parser.add_argument('-y', dest='confirm', action='store_false', help="skip confirmation", default=True)


# def backup(opts):
#   if has_image:
#     if not confirm("An image already exists in the dist folder. Do you want to overwrite?", default='no'):
#       print("Please move the distro.img file in the dist folder.")
#       exit(0)
#     else:
#       log.inf("Removing old image ...")
#       os.remove(image_path)
    
#   log.info("Copying image from drive ...")
#   run('dd conv=sparse bs=4M if=/dev/mmcblk0 of=/tmp/distro.img status=progress')
#   log.info("Converting image ...")
#   run('qemu-img convert -p -f raw -O qcow2 /tmp/distro.img /dist/distro.qcow2')
#   exit(0)


# Start command parser
def backup_parser(parsers, parent_parser, get_usage, env):
    description = "command for extracting an image from an SD card"
    
    parser = parsers.add_parser('backup', description=description, usage=get_usage('backup'))
    parser.add_argument('-d', dest='dist_path', type=str, help="storage path (default: /dist)", default='/dist')

import re
from lib.process import run

class Size():
  GIGABYTE = 1073741824
  MEGABYTE = 1048576
  BLOCK = 512
  

def get_image_size(image_path: str):
  part_list = run(f'guestfish add {image_path} : run : part-list /dev/sda', True)
  part_ends = re.findall('part_end: (\d+)', part_list)
  return int(part_ends[len(part_ends) - 1]) - Size.BLOCK + 1


def get_device_size(device_path: str):
  return int(run(f'blockdev --getsize64 {device_path}', True))


def get_virtual_size(image_path: str):
  image_info = run(f'qemu-img info {image_path}', True)
  return int(re.search('virtual size.+\((\d+) bytes', image_info).group(1))

import re, subprocess

def get_image_size(image_path: str):
  part_list = subprocess.getoutput(f'guestfish add {image_path} : run : part-list /dev/sda')
  part_ends = re.findall('part_end: (\d+)', part_list)
  return int(part_ends[len(part_ends) - 1]) - 511


def get_device_size(device_path: str):
  return int(subprocess.getoutput(f'blockdev --getsize64 {device_path}'))


def get_virtual_size(image_path: str):
  image_info = subprocess.getoutput(f'qemu-img info {image_path}')
  return int(re.search('virtual size.+\((\d+) bytes', image_info).group(1))

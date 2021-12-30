import subprocess
from lib.logger import log

# Run process 
def run(command: str, cancelable=False, get_output=True, **kwargs) -> str:
  try:
    log.debug(f"Running command: \"{command}\" ...")

    stdin = subprocess.PIPE if cancelable else None
    stdout = subprocess.PIPE if get_output else None

    process = subprocess.run(command, stdin=stdin, stdout=stdout, shell=True, **kwargs)

    output = None
    if process.stdout != None and process.stdout != '':
      output = process.stdout.decode('utf-8')
      log.debug(f'Output: {output}')

    process.check_returncode()
    return output


  except KeyboardInterrupt:
    print("") # Newline
    log.warn("Got keyboard interupt, stopping process ...")
    exit(1)

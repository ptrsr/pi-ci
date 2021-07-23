import subprocess
from lib.logger import log

# Run process 
def run(command, get_output=False, **kwargs):
    try: 
        if get_output: # Get output as string
            return subprocess.check_output(command, shell=True, **kwargs).decode('utf-8')
        else: # Pipe output to shell
            log.debug(f"Running command: \"{command}\"...")
            subprocess.Popen(command, stdin=subprocess.PIPE, shell=True, **kwargs).wait()
            log.debug("Command ran successfully")

    except KeyboardInterrupt:
        print('') # Print warning on newline after interupt
        log.warn("Got keyboard interupt, stopping process...")
        pass

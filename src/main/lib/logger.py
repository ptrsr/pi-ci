import logging

# Set logger color output
logging.addLevelName(logging.WARNING, '\033[93mWARN')
logging.addLevelName(logging.ERROR, '\033[91mERR ')
logging.addLevelName(logging.DEBUG, 'DBG ')

# Set custom logger format
log = logging.getLogger('PI-CI')
fh = logging.StreamHandler()
fh_formatter = logging.Formatter('[\033[1m%(levelname)s\033[0m] %(message)s')
fh.setFormatter(fh_formatter)
log.addHandler(fh)

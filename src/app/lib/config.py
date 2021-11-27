import os
from distutils.util import strtobool
from argparse import Namespace


def get_var(env_var: str):
    try:
        return bool(strtobool(env_var))
    except:
        return env_var


# Load environment variables from file
def get_env(env_file_path=None):
    return Namespace(**{ key: get_var(value) for key, value in os.environ.items() })

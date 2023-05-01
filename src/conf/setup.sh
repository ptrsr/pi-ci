#!/bin/sh
rm /etc/systemd/system/serial-getty@ttyAMA0.service

# Delete root password for passwordless login
passwd --delete root

# Disable setup script on next startup
systemctl disable setup.service

shutdown now

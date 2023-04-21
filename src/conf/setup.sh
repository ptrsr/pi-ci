#!/bin/sh
rm /etc/systemd/system/serial-getty@ttyAMA0.service

# Update and install ansible
apt-get update
apt-get install -y ansible

# Disable setup script on next startup
systemctl disable setup.service

shutdown now

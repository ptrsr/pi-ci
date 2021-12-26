#!/bin/sh
rm /etc/systemd/system/serial-getty@ttyAMA0.service
apt-get update
apt-get install -y ansible
systemctl disable setup.service
shutdown now

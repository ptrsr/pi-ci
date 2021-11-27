#!/bin/sh
apt-get update
apt-get install -y ansible
systemctl disable setup.service
shutdown now

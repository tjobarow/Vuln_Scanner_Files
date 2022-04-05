#!/bin/bash

sudo touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf
sudo systemctl restart NetworkManager

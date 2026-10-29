#!/bin/bash
sudo apt install -y bird2 unbound
sudo ./bird-unbound.sh
sudo cp -f ./unbound.conf /etc/unbound/unbound.conf
sudo cp -f ./bird.conf /etc/bird/bird.conf

# Restart services to apply custom configurations immediately
sudo systemctl restart bird unbound

# if you are certain that you have not edited your apt sources you may uncomment a line below
# and also comment out the line to enable port 80 in bird-unbound.sh
# sudo ./migrate-apt-https-only.sh

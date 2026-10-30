#!/bin/bash
sudo apt install -y bird2 unbound
sudo ./bird-unbound.sh

# Generate timestamped backup for unbound.conf if it exists
if [ -f /etc/unbound/unbound.conf ]; then
    sudo cp /etc/unbound/unbound.conf "/etc/unbound/unbound.conf-old-$(date +%Y%m%d-%H%M%S)"
fi
sudo cp -f ./unbound.conf /etc/unbound/unbound.conf

# Generate deterministic pseudo-IPv4 router ID from /etc/machine-id to prevent mesh router ID collisions
ROUTER_ID=$(md5sum /etc/machine-id 2>/dev/null | awk '{print $1}' | head -c 8 | perl -ne 'print join(".", unpack("C*", pack("H*", $_)))' 2>/dev/null)
if [ -z "$ROUTER_ID" ]; then
    ROUTER_ID="127.0.0.1"
fi

# Generate timestamped backup for bird.conf if it exists
if [ -f /etc/bird/bird.conf ]; then
    sudo cp /etc/bird/bird.conf "/etc/bird/bird.conf-old-$(date +%Y%m%d-%H%M%S)"
fi

# Deploy bird.conf with dynamically generated unique router id
sudo sed "s/^router id .*/router id ${ROUTER_ID};/" ./bird.conf | sudo tee /etc/bird/bird.conf > /dev/null

# Restart services to apply custom configurations immediately
sudo systemctl restart bird unbound

# if you are certain that you have not edited your apt sources you may uncomment a line below
# and also comment out the line to enable port 80 in bird-unbound.sh
# sudo ./migrate-apt-https-only.sh

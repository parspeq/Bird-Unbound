#!/bin/bash
set -euo pipefail

echo "🔄 Starting Bird-Unbound Uninstallation and Reversal..."

# 1. Stop and disable bird and unbound services
echo "🛑 Stopping and disabling bird and unbound services..."
sudo systemctl stop bird unbound || true
sudo systemctl disable bird unbound || true

# 2. Restore latest timestamped backups if available, or clean up config files
echo "📂 Restoring configuration backups if available..."
LATEST_BIRD_BACKUP=$(ls -t /etc/bird/bird.conf-old-* 2>/dev/null | head -n 1 || true)
if [ -n "$LATEST_BIRD_BACKUP" ]; then
    echo "   Restoring BIRD config from $LATEST_BIRD_BACKUP"
    sudo cp "$LATEST_BIRD_BACKUP" /etc/bird/bird.conf
else
    echo "   ⚠️ No BIRD backup found."
fi

LATEST_UNBOUND_BACKUP=$(ls -t /etc/unbound/unbound.conf-old-* 2>/dev/null | head -n 1 || true)
if [ -n "$LATEST_UNBOUND_BACKUP" ]; then
    echo "   Restoring Unbound config from $LATEST_UNBOUND_BACKUP"
    sudo cp "$LATEST_UNBOUND_BACKUP" /etc/unbound/unbound.conf
else
    echo "   ⚠️ No Unbound backup found."
fi

LATEST_NFT_BACKUP=$(ls -t /etc/nftables.conf-old-* 2>/dev/null | head -n 1 || true)
if [ -n "$LATEST_NFT_BACKUP" ]; then
    echo "   Restoring nftables config from $LATEST_NFT_BACKUP"
    sudo cp "$LATEST_NFT_BACKUP" /etc/nftables.conf
else
    echo "   ⚠️ No nftables backup found. Flushing nftables rules..."
    sudo nft flush ruleset || true
fi

# 3. Unmask and re-enable services that were disabled/masked
echo "🔓 Unmasking previously masked services (dnsmasq, avahi-daemon, cups)..."
for svc in dnsmasq avahi-daemon cups.service cups.socket cups.path; do
    sudo systemctl unmask "$svc" 2>/dev/null || true
done

# 4. Remove sysctl modifications added by bird-unbound.sh
echo "🧹 Cleaning up sysctl.conf modifications..."
if [ -f /etc/sysctl.conf ]; then
    sudo sed -i '/net.ipv4.conf.all.disable_ipv4=1/d' /etc/sysctl.conf
    sudo sed -i '/net.ipv4.conf.default.disable_ipv4=1/d' /etc/sysctl.conf
    sudo sed -i '/net.ipv6.conf.all.forwarding=1/d' /etc/sysctl.conf
    sudo sed -i '/net.ipv6.conf.default.forwarding=1/d' /etc/sysctl.conf
    sudo sed -i '/net.ipv6.conf.all.accept_dad=1/d' /etc/sysctl.conf
    sudo sed -i '/net.ipv6.conf.default.accept_dad=1/d' /etc/sysctl.conf
    sudo sed -i '/net.ipv6.conf.all.accept_ra=2/d' /etc/sysctl.conf
    sudo sed -i '/net.ipv6.conf.default.accept_ra=2/d' /etc/sysctl.conf
    sudo sed -i '/net.ipv6.conf.all.use_tempaddr=2/d' /etc/sysctl.conf
    sudo sed -i '/net.ipv6.conf.default.use_tempaddr=2/d' /etc/sysctl.conf
    sudo sed -i '/net.ipv6.conf.all.accept_redirects=0/d' /etc/sysctl.conf
    sudo sed -i '/net.ipv6.conf.default.accept_redirects=0/d' /etc/sysctl.conf
    sudo sysctl --system || true
fi

echo ""
echo "======================================================================"
echo "⚠️  UNINSTALLATION REVERSAL COMPLETED WITH IMPORTANT WARNINGS:"
echo "======================================================================"
echo "1. PACKAGE UNINSTALLATION:"
echo "   bird2 and unbound remain installed on your system. If you wish to"
echo "   remove them completely, run:"
echo "   sudo apt remove --purge bird2 unbound"
echo ""
echo "2. FIREWALL WARNING:"
echo "   The nftables firewall rules were restored or flushed. Your system"
echo "   may currently have an open or default firewall policy."
echo "   PLEASE DEPLOY AND CONFIGURE A REPLACEMENT FIREWALL (such as ufw or"
echo "   firewalld) immediately to secure your system:"
echo "   sudo apt install -y ufw && sudo ufw enable"
echo "======================================================================"

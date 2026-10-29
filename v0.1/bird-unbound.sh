#!/bin/bash
# Disable dnsmasq since it conflicts with unbound and is not needed now
sudo systemctl disable --now dnsmasq
# Mask it so no other service can accidentally trigger it
sudo systemctl mask dnsmasq

# Disable Avahi service for security unless you absolutely require network printers to work with it.
sudo systemctl disable --now avahi-daemon.service

# Disable cups if you do not use a locally hardware connected printer (USB or serial)
# Stop and disable the service and its network triggers
sudo systemctl disable --now cups.service cups.socket cups.path
# Mask the service (links it to /dev/null so it can never be turned back on by other apps)
sudo systemctl mask cups.service cups.socket cups.path

#enable nftables if not already enabled
sudo systemctl enable --now nftables

# Ensure the kernel-level packet configuration is properly configured
echo "net.ipv4.conf.all.disable_ipv4=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.conf.default.disable_ipv4=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.default.forwarding=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.accept_dad=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.default.accept_dad=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.accept_ra=2" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.default.accept_ra=2" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.use_tempaddr=2" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.default.use_tempaddr=2" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.accept_redirects=0" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.default.accept_redirects=0" | sudo tee -a /etc/sysctl.conf

# Apply sysctl settings immediately
sudo sysctl -p

# Rewrite the nftables configuration file to permit ICMPv6 forwarding
sudo tee /etc/nftables.conf << 'EOF'
#!/usr/sbin/nft -f
# Clear any active rules from memory first
flush ruleset

table inet filter {
    
    # -------------------------------------------------------------------------
    # INPUT CHAIN: Protects the gateway machine itself from direct attacks
    # -------------------------------------------------------------------------
    chain input {
        type filter hook input priority filter; policy drop;

        # Allow loopback traffic (internal system communication)
        iif "lo" accept

        # Allow returning internet traffic that the gateway explicitly requested
        ct state established,related accept

        # Crucial for IPv6: Allow essential ICMPv6 packets (Neighbor Discovery / PMTUD)
        ip6 nexthdr icmpv6 accept

        # Allow BIRD OSPFv3 multicast routing traffic from your internal neighbors
        iifname "e*" ip6 nexthdr ospf accept
        
        # Allow internal clients to query local Unbound DNS resolver on port 53
        iifname "e*" udp dport 53 accept
        iifname "e*" tcp dport 53 accept
    }

    # -------------------------------------------------------------------------
    # FORWARD CHAIN: Filters traffic passing THROUGH the gateway to the internet
    # -------------------------------------------------------------------------
    chain forward {
        type filter hook forward priority filter; policy drop;

        # Strict Outbound Policy: Only allow the internal plug-and-play ports (eth*)
        #    to exit to the internet if they are using HTTPS (443) or DNS (53)
        iifname "e*" tcp dport 443 accept
        iifname "e*" udp dport 53 accept
        
        # Allows Debian package mirrors
        iifname "e*" tcp dport 80 accept

        # Allow returning internet traffic back into your internal machines
        oifname "e*" ct state established,related accept
    }

    # -------------------------------------------------------------------------
    # OUTPUT CHAIN: Controls traffic originating FROM the machine itself
    # -------------------------------------------------------------------------
    chain output {
        type filter hook output priority filter; policy accept;
    }
}
EOF

# Reload the firewall to apply the changes instantly
sudo nft -f /etc/nftables.conf

# Confirm the live settings
echo "Settings Applied"


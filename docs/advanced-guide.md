# Advanced Installation & Configuration Guide: Bird-Unbound

This guide provides in-depth technical details, tuning options, and advanced administration instructions for deploying Bird-Unbound (`v0.1`) in production IPv6-only environments.

---

## 1. System Prerequisites & Network Topology

Bird-Unbound requires a modern Linux kernel with IPv6 enabled and support for `nftables`, `bird2` (BIRD routing daemon v2), and `unbound`.

- **Operating System:** Debian 11/12 or Ubuntu 20.04/22.04+ LTS.
- **Network Interface Naming:** Configuration scripts target network interfaces matching pattern `e*` (or equivalent interface naming like `e*` depending on system udev rules). Ensure firewall rules are applied on the appropriate interfaces before deployment.

---

## 2. Kernel Parameter Tuning (`sysctl`)

[`../v0.1/bird-unbound.sh`](../v0.1/bird-unbound.sh) applies kernel parameters to disable IPv4 entirely and harden IPv6 forwarding:

```ini
net.ipv4.conf.all.disable_ipv4=1
net.ipv4.conf.default.disable_ipv4=1
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
net.ipv6.conf.all.accept_dad=1
net.ipv6.conf.default.accept_dad=1
net.ipv6.conf.all.accept_ra=2
net.ipv6.conf.default.accept_ra=2
net.ipv6.conf.all.use_tempaddr=2
net.ipv6.conf.default.use_tempaddr=2
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
```

### Parameter Breakdown
- `accept_ra=2`: Accept Router Advertisements even when forwarding is enabled (essential for gateway auto-configuration).
- `use_tempaddr=2`: Prefer temporary privacy addresses (RFC 4941) for outgoing connections.
- `disable_ipv4=1`: Eliminates IPv4 stack attack surface.

---

## 3. Advanced BIRD OSPFv3 Mesh Configuration

[`../v0.1/bird.conf`](../v0.1/bird.conf) establishes an OSPFv3 routing mesh across dynamic internal interfaces (`e*`).

### Routing Filters & Security
- **Inbound Filter:**
  ```bird
  import filter {
      if net = ::/0 then accept;
      reject;
  };
  ```
  Prevents rogue internal nodes from injecting arbitrary subnet routes. Only default gateway advertisements (`::/0`) are accepted.
- **Outbound Filter:**
  ```bird
  export filter {
      if net = ::/0 then accept;
      reject;
  };
  ```
  Only nodes physically holding the internet transit link export `::/0`.

### Interface Timers & Cryptographic Authentication
```bird
interface "e*" {      
    type pointopoint;   
    hello 2;           # 2-second hello interval for rapid link-state detection
    dead 6;            # 6-second dead timer (3x hello)
    cost 100;          # Static cost override prevents metric manipulation attacks
    authentication cryptographic;
    password "SecureIntranetMeshKey123" {
        id 1;
        algorithm hmac sha256;
    };
};
```
*Note: In production environments, replace `"SecureIntranetMeshKey123"` with a cryptographically secure shared secret across all mesh nodes.*

---

## 4. Unbound Recursive DNS Hardening

[`../v0.1/unbound.conf`](../v0.1/unbound.conf) configures Unbound with enterprise privacy and security defaults:

- **Upstream Query Transport:**
  - `do-ip6: yes`
  - `do-ip4: no` (Forces pure IPv6 upstream resolution).
- **Access Control Lists (ACLs):**
  ```unbound
  access-control: ::/0 refuse
  access-control: ::1 allow
  access-control: 127.0.0.1 allow
  access-control: fe80::/10 allow
  ```
- **DNSSEC & Cache Poisoning Mitigations:**
  - Automatic trust anchor initialization (`auto-trust-anchor-file: "/var/lib/unbound/root.key"`).
  - Strict glue record checking (`harden-glue: yes`), stripped-DNSSEC detection (`harden-dnssec-stripped: yes`), and randomized case folding (`use-caps-for-id: yes`).
- **Privacy Controls:**
  - `hide-identity: yes`, `hide-version: yes`, and `qname-minimization: yes` prevent information leakage to authoritative nameservers.

---

## 5. nftables Firewall Architecture

The firewall rules defined in [`../v0.1/bird-unbound.sh`](../v0.1/bird-unbound.sh) enforce a zero-trust posture:

- **Input Chain (Gateway Protection):**
  - Permits loopback (`lo`), established/related sessions, and ICMPv6 neighbor discovery/PMTUD (`ip6 nexthdr icmpv6 accept`).
  - Permits OSPFv3 multicast routing (`ip6 nexthdr ospf`) and local DNS queries on port 53 from internal interfaces (`iifname "e*"`).
- **Forward Chain (Transit Filtering):**
  - Restricts internal forwarding (`iifname "e*"`) to TCP 443 (HTTPS), UDP 53 (DNS), and TCP 80 (Debian package mirrors).
  - Drops all unapproved forwarding traffic by default.

To inspect live firewall rules:
```bash
sudo nft list ruleset
```

### Firewall Compatibility & Removing Conflicting Packages

Bird-Unbound manages system packet filtering directly via `nftables`. Because other firewall frontends and managers take control of the Linux Netfilter subsystem, **Bird-Unbound may not work correctly** when multiple packet filters are active simultaneously.

Conflicting firewall packages such as `ufw`, `firewalld`, or `shorewall` will overwrite, flush, or conflict with the project's strict ingress and forwarding ruleset. Before installing and running Bird-Unbound, disable any conflicting services.

1. **UFW (Uncomplicated Firewall):**
   ```bash
   sudo ufw disable
   sudo apt remove --purge ufw
   ```
2. **Firewalld:**
   ```bash
   sudo systemctl stop firewalld
   sudo systemctl disable firewalld
   sudo apt remove --purge firewalld
   ```
3. **Shorewall:**
   ```bash
   sudo systemctl stop shorewall
   sudo systemctl disable shorewall
   sudo apt remove --purge shorewall
   ```
4. **Docker Network Rules:**
   If Docker is installed on the gateway, it automatically injects `FORWARD` chains that can bypass strict gateway drop policies. To prevent conflicts, ensure Docker's iptables management is disabled in `/etc/docker/daemon.json`:
   ```json
   {
     "iptables": false
   }
   ```
   *(Restart Docker via `sudo systemctl restart docker` after applying changes).*

---

## 6. APT HTTPS-Only Migration

To eliminate unencrypted package retrieval (`http://`), run [`../v0.1/migrate-apt-https-only.sh`](../v0.1/migrate-apt-https-only.sh):

1. Backs up existing `/etc/apt/sources.list` and `/etc/apt/sources.list.d/` into a timestamped directory.
2. Rewrites repository URIs from `http://` to `https://` (excluding localhost).
3. Enforces hard blocking of fallback transport via `/etc/apt/apt.conf.d/99force-https`:
   ```text
   Acquire::http::Proxy "false";
   Acquire::BlockHTTP "true";
   ```
4. **Firewall Adjustment for Port 80:** When fully migrating to HTTPS-only package management, remember to comment out or remove the rule in [`../v0.1/bird-unbound.sh`](../v0.1/bird-unbound.sh) that permits outbound HTTP traffic before finalizing the change.

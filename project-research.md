# Project Research Report: Bird-Unbound

## Overview
Bird-Unbound (`v0.1`) is a lightweight networking and DNS security configuration package designed for IPv6-only environments utilizing the BIRD routing daemon (`bird2`) and the Unbound recursive DNS resolver (`unbound`). The project enforces strict firewall policies via `nftables`, disables conflicting network services (`dnsmasq`, `avahi-daemon`, `cups`), configures kernel IPv6 forwarding and privacy parameters, and provides an optional APT HTTPS-only migration tool.

---

## Architecture & Implementation Details

### 1. Installation & Orchestration Script
- **File Path:** [`v0.1/install.sh`](v0.1/install.sh)
- **Role:** Installs `bird2` and `unbound`, executes [`v0.1/bird-unbound.sh`](v0.1/bird-unbound.sh) to configure system services, kernel parameters, and nftables firewall rules, and deploys configuration files.
- **Dynamic Router ID Generation:** Automatically computes a deterministic 32-bit pseudo-IPv4 router ID derived from [`/etc/machine-id`](/etc/machine-id) using `md5sum` and `perl`, substituting it dynamically into `/etc/bird/bird.conf` during installation to prevent OSPFv3 routing ID collisions across mesh participants.
- **Pre-Deployment Configuration Backups:** Automatically generates timestamped backups (e.g., `-old-YYYYMMDD-HHMMSS`) of existing configuration files (`/etc/bird/bird.conf`, `/etc/unbound/unbound.conf`, `/etc/nftables.conf`) in their respective directories prior to overwriting them during deployment.

### 2. Network & Firewall Configuration
- **File Path:** [`v0.1/bird-unbound.sh`](v0.1/bird-unbound.sh)
- **Service Management:**
  - Disables and masks `dnsmasq` ([`v0.1/bird-unbound.sh`](v0.1/bird-unbound.sh)).
  - Disables `avahi-daemon.service` ([`v0.1/bird-unbound.sh`](v0.1/bird-unbound.sh)).
  - Disables and masks `cups.service`, `cups.socket`, and `cups.path` ([`v0.1/bird-unbound.sh`](v0.1/bird-unbound.sh)).
- **Kernel Parameter Tuning:**
  - Disables IPv4 via `net.ipv4.conf.all.disable_ipv4=1` and `net.ipv4.conf.default.disable_ipv4=1` ([`v0.1/bird-unbound.sh`](v0.1/bird-unbound.sh)). *(Note: Well-suited for pure IPv6 desktop endpoints, but can impact servers and container runtimes expecting IPv4 loopback).*
  - Configures IPv6 forwarding, Router Advertisements (`accept_ra=2`), and temporary addresses (`use_tempaddr=2`) ([`v0.1/bird-unbound.sh`](v0.1/bird-unbound.sh)).
- **Firewall Rules (`nftables`):**
  - **Input Chain:** Drops all ingress by default, permitting loopback traffic, established/related sessions, essential ICMPv6 (`ip6 nexthdr icmpv6 accept`), and BIRD OSPFv3 multicast routing on `[ewubif]*` interfaces ([`v0.1/bird-unbound.sh`](v0.1/bird-unbound.sh)).
  - **Forward Chain:** Drops all forwarding by default, allowing outbound TCP port 443, UDP/TCP port 53, and TCP port 80 (for Debian mirrors) on `[ewubif]*` interfaces, along with returning traffic ([`v0.1/bird-unbound.sh`](v0.1/bird-unbound.sh)).

### 3. BIRD Routing Daemon Configuration
- **File Path:** [`v0.1/bird.conf`](v0.1/bird.conf)
- **Router ID:** Dynamically generated per node during installation via [`v0.1/install.sh`](v0.1/install.sh).
- **Protocols:**
  - `protocol kernel`: Syncs IPv6 routes bi-directionally with the operating system kernel ([`v0.1/bird.conf`](v0.1/bird.conf)).
  - `protocol device`: Monitors network interfaces with a 10s scan interval ([`v0.1/bird.conf`](v0.1/bird.conf)).
  - `protocol ospf v3 intranet_mesh`: Handles plug-and-play IPv6 routing ([`v0.1/bird.conf`](v0.1/bird.conf)).
    - **Martian Prefix Filtering (`MARTIANS_V6`):** Explicitly defines reserved/bogon/loopback/link-local/multicast IPv6 prefixes (`::1/128`, `fe80::/10`, `ff00::/8`, etc.) and rejects them in import and export filters.
    - **Import/Export Filters:** Accepts and exports only default routes (`::/0`) while filtering martians, preventing rogue path injections ([`v0.1/bird.conf`](v0.1/bird.conf)).
    - **Interface Settings (`[ewubif]*`):** Point-to-point type, 2s hello timer, 6s/10s dead timer, static metric cost of `100`, and cryptographic authentication using HMAC SHA-256 (`SecureIntranetMeshKey123`) ([`v0.1/bird.conf`](v0.1/bird.conf)).

### 4. Unbound DNS Resolver Configuration
- **File Path:** [`v0.1/unbound.conf`](v0.1/unbound.conf)
- **Networking:** Listens on `::0`, `127.0.0.1`, and `::1` on port 53 ([`v0.1/bird.conf`](v0.1/bird.conf)). Enables IPv6 upstream queries (`do-ip6: yes`) and disables IPv4 upstream queries (`do-ip4: no`) ([`v0.1/bird.conf`](v0.1/bird.conf)).
- **Access Control:** Refuses all public queries (`access-control: ::/0 refuse`) while explicitly permitting localhost (`::1`, `127.0.0.1`) and IPv6 link-local neighbors (`fe80::/10`) ([`v0.1/bird.conf`](v0.1/bird.conf)).
- **DoS Mitigation:** Generous rate limiting (`ip-ratelimit: 1000`, `ratelimit: 1000`) enabled to protect against query floods and amplification attempts without impacting legitimate mesh traffic.
- **Security & Privacy:** Automatic DNSSEC validation (`auto-trust-anchor-file`), cache poisoning mitigations (`harden-glue`, `harden-dnssec-stripped`, `use-caps-for-id`), and privacy enhancements (`hide-identity`, `hide-version`, `qname-minimization`) ([`v0.1/bird.conf`](v0.1/bird.conf)).

### 5. APT HTTPS-Only Migration Tool
- **File Path:** [`v0.1/migrate-apt-https-only.sh`](v0.1/migrate-apt-https-only.sh)
- **Role:** Backs up existing APT sources, replaces HTTP repositories with HTTPS in `/etc/apt/sources.list` and `/etc/apt/sources.list.d/`. Enforces strict blocking of unencrypted HTTP fallback transport via `/etc/apt/apt.conf.d/99force-https`.

---

## Critical Dependencies
- **`bird2`**: Routing daemon responsible for OSPFv3 dynamic mesh routing.
- **`unbound`**: Recursive DNS resolver with DNSSEC validation.
- **`nftables`**: Modern Linux packet filtering framework enforcing gateway security and packet forwarding rules.

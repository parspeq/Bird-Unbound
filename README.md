# Bird-Unbound
Bird-Unbound (`v0.1`) is designed for the easy and secure setup of a configurationless IPv6 mesh topology. When all participating machines run the application, it automatically establishes an IPv6-only mesh network arrangement that restricts outbound transit exclusively to secure HTTPS connections. Bird-Unbound (`v0.1`) has no function other than securely configuring the BIRD routing daemon (`bird2`) and the Unbound recursive DNS resolver (`unbound`). By configuring these packages, it enables the easy and secure setup of a configurationless IPv6 mesh topology.

---

## What are BIRD and Unbound?

- **BIRD (`bird2`):** An advanced dynamic routing daemon that handles plug-and-play OSPFv3 mesh routing, securely peering connected nodes and automatically propagating routes across the network without manual intervention.
 
- **Unbound (`unbound`):** A high-performance recursive and validating DNS resolver that provides secure, DNSSEC-validated name resolution and local query handling for mesh participants.

*(Note: For a simple, flat star-topology network where every machine plugs directly into a single home router or switch, BIRD is not strictly necessary as machines learn gateways via IPv6 Router Advertisements. However, BIRD is essential for mesh, multi-hop, and ad-hoc network topologies. Unbound is essential to ensuring DNS for the varied topologies.)*

---

## Architecture & Components

| Component | File Path | Role |
| :--- | :--- | :--- |
| **Installation Script** | [`v0.1/install.sh`](v0.1/install.sh) | Installs `bird2` and `unbound`, applies network/firewall configurations, and deploys configuration files. |
| **Network & Firewall Setup** | [`v0.1/bird-unbound.sh`](v0.1/bird-unbound.sh) | Disables conflicting services (`dnsmasq`, `avahi-daemon`, `cups`), tunes kernel IPv6 parameters, and applies strict `nftables` ingress/forwarding rules permitting only HTTPS egress. |
| **BIRD Routing Config** | [`v0.1/bird.conf`](v0.1/bird.conf) | Configures OSPFv3 dynamic mesh routing with route filters (`::/0`) and cryptographic authentication (HMAC SHA-256). |
| **Unbound DNS Config** | [`v0.1/unbound.conf`](v0.1/unbound.conf) | Configures recursive DNS resolver with IPv6 upstreaming, DNSSEC validation, cache poisoning mitigations, and privacy hardening. |
| **APT HTTPS Migration** | [`v0.1/migrate-apt-https-only.sh`](v0.1/migrate-apt-https-only.sh) | Optional utility to migrate APT package sources to HTTPS and enforce strict blocking of unencrypted HTTP fallback. |

---

## Quick Start & Installation

1. Navigate to the release directory:
   ```bash
   cd v0.1
   ```
2. Execute the installation script with root privileges:
   ```bash
   sudo ./install.sh
   ```

*(Optional)* To enforce strict HTTPS-only package management via APT, uncomment the migration line in [`v0.1/install.sh`](v0.1/install.sh) or run:
```bash
sudo ./migrate-apt-https-only.sh
```

---

## Security & Firewall Specifications

- **IPv6-Only Mesh Enforcement:** Disables IPv4 stack at the kernel level and establishes a configurationless peer-to-peer IPv6 routing topology.
- **Firewall (`nftables`):**
  - **Input Chain:** Drops all ingress by default; allows loopback, established/related sessions, essential ICMPv6 Neighbor Discovery, BIRD OSPFv3 multicast routing (`iifname "[ewubif]*"`), and local Unbound DNS queries on port 53.
  - **Forward Chain:** Drops all forwarding by default; permits outbound HTTPS (TCP 443), DNS (UDP 53), and Debian mirrors (TCP 80 if needed) on `[ewubif]*` interfaces, restricting all other outbound transit.
- **Routing Security (`BIRD OSPFv3`):**
  - Enforces strict import/export filters accepting only default routes (`::/0`).
  - Implements point-to-point interface settings with 2s hello and 6s dead timers, metric cost `100`, and cryptographic authentication (`SecureIntranetMeshKey123`).
- **DNS Resolver (`Unbound`):**
  - Listens on `::0`, `127.0.0.1`, and `::1` on port 53.
  - Refuses public recursion (`access-control: ::/0 refuse`) while permitting localhost and IPv6 link-local neighbors (`fe80::/10`).
  - Enables automatic DNSSEC validation (`auto-trust-anchor-file`), hardening against cache poisoning (`harden-glue`, `harden-dnssec-stripped`, `use-caps-for-id`), and qname minimization.

---

## Documentation & Further Reading
- **[Advanced Installation & Configuration Guide](docs/advanced-guide.md)**: Deep-dive instructions on kernel tuning, OSPFv3 mesh parameters, Unbound hardening, firewall rules, and APT HTTPS migration.
- **[Project Research Report](project-research.md)**: Comprehensive technical breakdown of the architecture and implementation details.

---

## ⚠️ Important Warning & Configuration Notice

**Warning:** Installing and running Bird-Unbound makes significant, system-wide modifications to your host network configuration. These changes include:
- Disabling the IPv4 network stack at the kernel level.
- Overwriting system firewall rules (`nftables`) with a zero-trust policy that blocks unapproved ingress and egress.
- Disabling and masking conflicting network services (`dnsmasq`, `avahi-daemon`, `cups`).
- Reconfiguring default routing via BIRD OSPFv3 and DNS resolution via Unbound.
- **Firewall Package Conflicts:** Bird-Unbound manages `nftables` directly. It currently **may not work correctly** if other firewall frontends or managers (such as `ufw`, `firewalld`, or `shorewall`) are installed, enabled, or active, as they will overwrite or conflict with the project's strict firewall ruleset.

Please carefully review all scripts and configurations (`v0.1/`) to understand their impact on your environment before installation on production or non-isolated systems.

---

## 🌐 IPv6-Only Network Compatibility Notice

**Note on IPv6-Only Limitations:** Because this application enforces a pure IPv6-only network environment and blocks IPv4 connectivity, certain legacy websites, non-dual-stack services, APIs, and older content providers that rely exclusively on IPv4 addresses without IPv6 (AAAA) records will not be reachable. In general, this affects:
- Legacy websites and self-hosted services lacking IPv6 support.
- Older corporate or academic portals that have not adopted IPv6 addressing.
- Certain third-party APIs, CDNs, or authentication providers operating exclusively over IPv4.

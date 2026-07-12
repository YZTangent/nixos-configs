# Network Inspection Reference

Commands and concepts for inspecting routing, DNS, and interfaces on Linux.

---

## Commands

### Routing table
```sh
ip route show
```
Shows all routes: default gateway, directly connected subnets, and virtual network routes.

Key fields:
- `default via <IP> dev <iface>` — default gateway and which interface it goes through
- `<subnet> dev <iface> proto kernel` — local subnet, auto-added by kernel when interface is up
- `proto dhcp` — route assigned by DHCP
- `metric <N>` — route priority; lower wins

### DNS resolver
```sh
cat /etc/resolv.conf
```
Shows which nameserver(s) the system queries for DNS. Often managed by NetworkManager or resolvconf — manual edits may be overwritten.

On systemd-resolved systems, use instead:
```sh
resolvectl status
```

### Interface addresses
```sh
ip addr show
# or for a specific interface:
ip addr show wlp195s0
```
Lists every network interface, its MAC, IPs (v4 and v6), and state (`UP`/`DOWN`/`UNKNOWN`).

Key fields:
- `state UP` — interface is active
- `inet <IP>/<prefix>` — IPv4 address
- `dynamic` — assigned by DHCP
- `secondary` — additional IP on the same interface (e.g. static alias)
- `inet6 fe80::...` — link-local IPv6, auto-assigned on every interface

### NetworkManager structured view
```sh
nmcli dev show | grep -E 'DNS|DOMAIN|GATEWAY|ADDRESS'
```
Structured per-interface view of IPs, gateway, and DNS. Useful when multiple interfaces are up.

---

## Concepts

### DHCP vs static IP
- **DHCP** (`dynamic`): IP leased from router/DHCP server, expires after lease time
- **Static** (`proto 0x12` or `secondary`): Manually or config-assigned, persists across reboots

### Secondary IPs
A single physical interface can hold multiple IPs. Common use cases: hosting multiple services, Cloudflare tunnel binding, VIPs.

### Virtual interfaces
| Interface pattern | What it is |
|---|---|
| `docker0` | Docker bridge network (`172.17.0.0/16`) |
| `cni0` | k3s/CNI pod bridge (`10.42.0.0/24`) |
| `flannel.1` | Flannel VXLAN overlay for k3s inter-node traffic |
| `veth*` | Virtual ethernet pairs — one end in host, one end in a container/pod network namespace |

### CNI / Flannel (k3s pod network)
k3s uses Flannel as its CNI (Container Network Interface). Each pod gets an IP from `10.42.0.0/24`. Traffic between pods on the same node goes through `cni0`; cross-node traffic is encapsulated via `flannel.1`.

### Link-local IPv6 (`fe80::`)
Auto-assigned on every interface; scoped to the local link only (not routable). Used for neighbor discovery and some internal protocols. Not a sign of full IPv6 connectivity.

---

## This host (strix-halo) — state as of 2026-07-13

| Item | Value |
|---|---|
| Active interface | `wlp195s0` (WiFi) |
| DHCP IP | `192.168.1.124/24` |
| Static secondary IP | `192.168.1.200/24` (NixOS config) |
| Gateway | `192.168.1.254` |
| DNS | `192.168.1.254` (router handles DNS) |
| k3s pod subnet | `10.42.0.0/24` via `cni0` |
| Docker bridge | `172.17.0.0/16` via `docker0` (down) |

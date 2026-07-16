# ADR: Bypass router DNS with local caching resolver + DNS-over-TLS

Date: 2026-07-15
Status: accepted

## Context

Intermittent browser connection failures on strix-halo ("site can't be reached" on github/google, fixed by reload spam). Diagnosis showed the Singtel router's DNS forwarder (`192.168.1.254`, sole nameserver via DHCP) returns `5(REFUSED)` under load:

- Mixed-type query bursts trip its throttle reliably (18-30/60 REFUSED across runs); MX queries alone trip it; once tripped, ALL query types get REFUSED for a penalty window — including plain A lookups for arbitrary domains.
- The throttle is shared router state: aggregate load from all household devices can put it in throttle, then any page load catches REFUSED.
- No local DNS cache existed (systemd-resolved inactive, nscd host caching off), so every browser cache-miss hit the router over UDP.
- Secondary: ~3-5% UDP timeout loss even querying 1.1.1.1 directly.

## Decision

Enable systemd-resolved fleet-wide (`modules/network.nix`) as local caching resolver, with DNS-over-TLS upstreams (Cloudflare 1.1.1.1/1.0.0.1, Quad9 9.9.9.9) and `Domains=~.` so all lookups use global DNS, ignoring the router's DHCP-provided nameserver.

- Cache absorbs page-load query bursts locally.
- DoT (TCP) bypasses the router forwarder entirely and eliminates residual UDP loss.
- `dnssec = "allow-downgrade"` avoids hard failures on networks that break DNSSEC.

## Alternatives rejected

- **Plain-UDP nameserver swap** (`networking.nameservers` only): keeps the 3-5% UDP loss and burst exposure; no cache.
- **Router/ISP-side fix**: throttle behavior not user-configurable on ISP-supplied router.

## Consequences

- All hosts stop using LAN router DNS; local hostname resolution via router would break (none in use).
- DNS visible to Cloudflare/Quad9 instead of ISP; encrypted in transit on LAN.
- k3s/CoreDNS unaffected (own resolution path).

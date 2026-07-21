# Intermittent connection failures on strix-halo — investigation log

Started 2026-07-15. Symptom: browsing github/google intermittently fails
("connection failed" / Firefox `NS_ERROR_CONNECTION_REFUSED`-class errors),
fixed by reload-spamming. Not frequent, but frequent enough to be annoying.

Three distinct issues were found sharing the same host and time window.
Two are fixed. The primary suspect (WiFi power-save) has a fix identified
but not yet applied/confirmed.

---

## Issue 1 — Router DNS forwarder throttling (secondary, FIXED)

**Symptom in isolation:** `host`/`dig` lookups against the router
(`192.168.1.254`, the Singtel-supplied gateway, DHCP-assigned as sole
nameserver) started returning `5(REFUSED)` under burst load.

**How it was found:** burst-tested the router's forwarder directly:

```sh
for i in $(seq 1 60); do host -W 2 github.com 192.168.1.254 >/dev/null 2>&1 || echo FAIL $i; done
```

30-60% of a 60-query burst came back REFUSED, first failure ~20-30 queries
in. Isolated further: mixed query types (`host` sends A+AAAA+MX by
default) tripped it fastest; once tripped, the penalty applied to *all*
query types for a window, not just the triggering one. A 25-domain
parallel burst (page-load-sized) passed clean from a cold state — the
throttle is shared router state that depends on aggregate household load,
which is why it wasn't reliably reproducible in isolation.

**Root cause:** the router's own recursive-DNS budget, not this host —
confirmed by querying 1.1.1.1/8.8.8.8 directly, which showed no REFUSED
(some plain UDP timeout loss, ~3-5%, but different failure mode).

**Fix (applied, live since 2026-07-15):** `modules/network.nix` — enabled
`services.resolved` with local caching and DNS-over-TLS to
Cloudflare (1.1.1.1/1.0.0.1) and Quad9 (9.9.9.9), `Domains = "~."` so all
lookups bypass the router's nameserver entirely. Verified via `resolvectl
status` (`+DNSOverTLS`, correct servers) and re-running the burst test
(0/60 failures afterward).

Commit: `337c7c5 feat: local caching resolver with DNS-over-TLS, bypassing router DNS`
ADR: `docs/adr/2026-07-15-bypass-router-dns.md`

**Verdict:** real bug, fixed, but ruled out as the main symptom — this
produces DNS-resolution-stage failures (`NS_ERROR_UNKNOWN_HOST`), and the
user's actual browser errors are TCP-stage (`NS_ERROR_CONNECTION_REFUSED`
/ timeouts *after* successful resolution). See Issue 3.

---

## Issue 2 — k3s crashloop (unrelated tangent, FIXED)

Discovered while investigating whether the newly-added `nixos-server` k3s
stack (added 2026-07-13, `hosts/strix-halo.nix`) was generating enough DNS
load to explain Issue 1's timing. It wasn't a significant contributor
(pods resolve via local CoreDNS, not the router — only their own external
cache-misses go upstream), but a real, unrelated bug turned up:

**Symptom:** `journalctl -u k3s` showed k3s fatal-exiting and
systemd-restarting every 5 seconds, continuously, whenever the interface
held two global IPv4 addresses: the DHCP lease (`192.168.1.124`) and the
keepalived-managed VIP (`192.168.1.200`) used for HA API-server access.
k3s refuses to autodetect a node IP in that situation
(`multiple global unicast addresses defined for wlp195s0`). It only ever
ran successfully by winning a boot-time race against keepalived claiming
the VIP; any restart after that failed forever, leaving orphaned
containerd-shim pods (CoreDNS, Traefik, metrics-server,
local-path-provisioner, a helm job) running under no supervision.

**Fix:** in `~/code/nixos-server` (the `github:yztangent/nixos-server`
flake input), `services/k3s.nix` now derives node-ip at *runtime* — a
preStart script picks "the global IPv4 on the flannel interface that
isn't the VIP" and writes it to a k3s config drop-in
(`/etc/rancher/k3s/config.yaml.d/node-ip.yaml`), rather than requiring a
per-host Nix option (which would break the "same compute profile on N
nodes" requirement). Also added `--tls-san=<vip>` so the always-on k3s API
TLS cert is valid when reached via the floating VIP.

Commit (in nixos-server repo): `9ccd459 fix(k3s): derive node-ip at runtime and add VIP to tls-san`

**Note:** k3s's own API is always TLS (no plaintext mode exists in
Kubernetes since the old insecure port was removed) — `--tls-san` doesn't
turn TLS on, it just adds the VIP to the cert's SAN list so joins via the
VIP don't fail cert validation.

---

## Issue 3 — WiFi power-save stalls (PRIMARY SUSPECT, fix identified, not yet confirmed)

This is believed to be the actual cause of the user's symptom.

### Signature

- Browser shows connection *refused/timeout*, not DNS failure — so this
  happens after successful name resolution.
- Outbound TCP SYNs to multiple, unrelated destinations (github.com,
  google.com, wiki.nixos.org, and raw IPs 1.1.1.1/9.9.9.9) go unanswered
  simultaneously for a period, then everything recovers together.
- During failures, ICMP to the router is *usually* 0% loss (once caught at
  100% loss too — see episode log), and DNS resolves in ~1ms — so the LAN
  hop and the router's control plane are generally still alive.
- `/proc/net/dev` RX rate on `wlp195s0` drops to literal 0 B/s during
  failure windows.
- Episode duration: ~5-60+ seconds. Frequency: roughly 20-30/day, fairly
  steady, no correlation found with local cron/systemd timers, k3s
  activity, or any host-side load.
- Zero episodes during long idle stretches (multi-hour), resuming when
  host activity picks up — but the failures themselves show no
  correlation with what that activity actually is (curl bursts, cron,
  etc. were all individually ruled out — see "Ruled out" below).
- No corresponding kernel/NetworkManager/wpa_supplicant log lines during
  failure windows (no deauth, no reassociation, no scan) — this is the
  key fact that rules out ordinary WiFi disconnects/roaming and points at
  something below the netdev-event layer: a driver/firmware-level radio
  stall while still associated.

### Hardware/driver identified

```sh
$ basename $(readlink /sys/class/net/wlp195s0/device/driver)
mt7925e
```

MediaTek MT7925 (Wi-Fi 7 chipset), driver `mt7925e`. This chipset+driver
combination has widely reported issues on Linux with power-save-related
radio stalls: the card enters its sleep/wake (beacon-driven) power-save
cycle, and the wake or buffered-frame-retrieval handshake occasionally
fails silently — no disconnect, no error, just a dead radio for several
seconds until it self-recovers.

Checked at investigation time:
```sh
$ nmcli -f 802-11-wireless.powersave con show 'SINGTEL-XH7A(5G)'
802-11-wireless.powersave: 0 (default)   # = defer to driver default = power-save ON for mt7925
$ cat /sys/module/*/parameters/disable_aspm
N                                         # ASPM enabled
```

### Ruled out

- **DNS** — failures happen with DNS answering in ~1ms from local cache;
  Issue 1's fix is already live and didn't change episode frequency.
- **Router DNS throttle (Issue 1)** — different failure signature
  entirely (that one is resolution-stage, this is connect-stage).
- **Server-side** — multiple unrelated destinations fail simultaneously.
- **Local firewall/conntrack** — `nf_conntrack_count` checked normal
  (45/1048576) during quiet periods; no iptables REJECT rules found.
- **k3s/nixos-server load** — k3s pod DNS resolves locally via CoreDNS,
  doesn't hit the router; only external cache-misses do, and those are
  infrequent/bursty, not steady-state. k3s was also crashlooping (down)
  for much of the observation window (see Issue 2) yet episodes continued
  — rules out k3s as the cause.
- **WiFi scan/roam events** — no corresponding kernel log entries;
  manually triggering `nmcli dev wifi rescan` during a controlled test
  caused no failures.
- **Local upload bursts / self-induced congestion** — bandwidth log shows
  RX/TX both near-zero during several failure windows (not saturated).
- **Cron jobs** — initially suspected correlation with the (since-removed,
  see daemons.nix) minute-ly canvas cron; retracted, this was selection
  bias (it fires every single minute, so it "correlates" with anything).

### Proposed fix (not yet applied)

Runtime A/B test:
```sh
sudo nmcli con modify 'SINGTEL-XH7A(5G)' 802-11-wireless.powersave 2 && \
sudo nmcli con up 'SINGTEL-XH7A(5G)'
```
(`2` = NetworkManager's "disable power-save" value.)

If confirmed (episode rate drops to ~0 over a comparable observation
window), make it declarative in `modules/network.nix`:
```nix
networking.networkmanager.wifi.powersave = false;
```
If stalls persist even with NM-level power-save off, the next lever is
the kernel module parameter: `options mt7925e disable_aspm=Y` (ASPM —
PCIe Active State Power Management — is a separate, lower-level power
state that can cause similar symptoms on this chipset).

**As of this writing the toggle has not been applied** — `nmcli -g
802-11-wireless.powersave con show 'SINGTEL-XH7A(5G)'` still reports
`default`. The baseline dataset (149+ episodes as of 2026-07-21, growing)
exists precisely so the A/B comparison is meaningful once it is.

---

## Methodology / instrumentation

All ad hoc, run as the regular user (no root needed for read-only
network diagnostics). Two long-running background loggers were set up
via the `Monitor` tool and left running across the whole investigation
(both still running as of this writing):

**1. Outage episode logger** — 1Hz raw TCP connect attempts (`/dev/tcp`,
bypasses DNS and TLS to isolate the transport layer) to `github.com:443`,
logs the start/end of each run of consecutive failures, and specifically
flags any run reaching 30s+:

```sh
log=<scratchpad>/outage-episodes.log
run=0; ps_last=$(nmcli -g 802-11-wireless.powersave con show 'SINGTEL-XH7A(5G)' 2>/dev/null)
while true; do
  if timeout 4 bash -c '</dev/tcp/github.com/443' 2>/dev/null; then
    [ "$run" -gt 0 ] && echo "$(date +%F' '%T) episode ended: ${run} consecutive fails" >> "$log"
    run=0
  else
    run=$((run+1))
    [ "$run" -eq 1 ] && echo "$(date +%F' '%T) episode start" >> "$log"
    [ "$run" -eq 8 ] && echo "$(date +%T) LONG OUTAGE: 30s+ of failed connects (powersave=$ps_last)"
  fi
  ps_now=$(nmcli -g 802-11-wireless.powersave con show 'SINGTEL-XH7A(5G)' 2>/dev/null)
  if [ "$ps_now" != "$ps_last" ]; then
    echo "$(date +%T) POWERSAVE CHANGED: $ps_last -> $ps_now (A/B test begins)"
    echo "$(date +%F' '%T) powersave changed: $ps_last -> $ps_now" >> "$log"
    ps_last=$ps_now
  fi
  sleep 2
done
```

Log location (live process still appends to the scratchpad copy; a
snapshot as of 2026-07-21 is checked in at `docs/spike/logs/outage-episodes.log`
— **re-copy from the scratchpad path below before doing the A/B
comparison**, since the checked-in copy predates the power-save toggle):
```
/tmp/claude-1000/-home-yztangent--home/5e2cf322-6738-4519-8a93-e0093fb2f32b/scratchpad/outage-episodes.log
```
Format: one line per episode start/end, plus a `POWERSAVE CHANGED` marker
whenever the toggle is applied — that marker is what splits the log into
"before" and "after" for the A/B comparison. As of 2026-07-21 (snapshot):
149 episode-starts logged, no `POWERSAVE CHANGED` marker yet (toggle not
applied), worst single episode so far 18 consecutive failed connects
(~60-70s).

**2. Bandwidth recorder** — per-second RX/TX byte-rate on `wlp195s0` from
`/proc/net/dev`, used to correlate failure windows against actual link
activity (ruled out local congestion as the cause):
```sh
f=<scratchpad>/wlp-rates.log
prx=0; ptx=0
while true; do
  read rx tx < <(awk '/wlp195s0/{print $2, $10}' /proc/net/dev)
  [ "$prx" != 0 ] && echo "$(date +%T) rx_Bps=$((rx-prx)) tx_Bps=$((tx-ptx))" >> "$f"
  prx=$rx; ptx=$tx
  sleep 1
done
```
Log location (same caveat — scratchpad, not persisted):
```
/tmp/claude-1000/-home-yztangent--home/5e2cf322-6738-4519-8a93-e0093fb2f32b/scratchpad/wlp-rates.log
```
This one grows unbounded (~1.4MB/day) and was manually truncated once
(2026-07-21, kept last 50k lines ≈ 14h) — no automatic rotation, revisit
if it's still needed.

**Earlier probe iterations** (superseded, notes kept for anyone repeating
this kind of investigation):
- v1-v2: sequential `curl` to 3 sites every 10s — too coarse, episodes are
  5-15s and easy to straddle between polls.
- v3-v5: added in-window parallel pings (router/LAN-neighbor/WAN) fired
  immediately on detecting a failure, to localize which hop was down.
  Useful for a few individual episodes (confirmed router ICMP occasionally
  also drops during an episode) but `sleep 10` between poll cycles meant
  many episodes were still missed or only partially captured.
- v6 → the 1Hz continuous connect-loop above (kept) is what finally gave
  reliable episode boundaries and durations.

**Tooling note:** `dig` is not installed on strix-halo; `host` was used
instead for manual DNS burst-testing. `host` sends A+AAAA+MX queries by
default (3x amplification vs a single query type) — relevant if
replicating the Issue 1 burst tests, since it reaches the router's
throttle threshold faster than a single-record-type tool would.

---

## Current open items

1. **Apply the WiFi power-save A/B test** (see Issue 3) — the one
   remaining step to close this investigation. Run the `nmcli` toggle,
   let the logger accumulate "after" data for a comparable window to the
   149-episode baseline, then check for a `POWERSAVE CHANGED` marker
   followed by an absence of `episode start` lines.
2. Once confirmed, make the fix declarative (`modules/network.nix`) and
   remove/stop the two background loggers.
3. If power-save-off doesn't fully resolve it, try `disable_aspm=Y` on
   the `mt7925e` module next.

# Spike: k3s stuck at boot — embedded etcd membership vs. changed node IP

Date: 2026-08-22
Status: investigation complete; recovery pending (needs sudo)

## Summary

Single-node k3s (`--cluster-init`, embedded etcd) failed to become ready after a reboot because the host's IP changed. The etcd membership record stores the node's *peer URL* from the original bootstrap (July 10) — `https://192.168.1.124:2380` — but after the network changed, k3s computes a different advertise address (`192.168.179.136`). The mismatch never resolves, and the service loops forever in `activating (start)`:

```
Failed to test etcd connection: this server is not a member of the etcd cluster.
Found [strix-halo-f917b42f=https://192.168.1.124:2380], expect: strix-halo-f917b42f=https://192.168.179.136:2380
```

---

# Part I — Theory: the k3s/etcd network & identity model

> **Terminology note.** k3s calls the two node roles **server** and **agent**. The k3s binary's own help says: `server — Run management server`, `agent — Run node agent`.
>
> | k3s term | Standard Kubernetes term | Runs |
> |---|---|---|
> | **server** | *control-plane node* | kube-apiserver, embedded etcd, controller-manager, scheduler (+ kubelet, so it can run workloads) |
> | **agent** | *worker node* | kubelet + kube-proxy + flannel only — no control plane |
>
> Standard K8s historically called these *minion* → *master / worker* → (since 1.20) *control plane / worker*. k3s chose *server / agent* to emphasize the connection model: agents dial **to** the server (the kube-*api-server*), never the reverse. A small k3s cluster often has **no agents** — server nodes schedule workloads by default, so every node is a server. The distinction is load-bearing in §8 (join semantics).

This part is the mental model that explains the incident — and every future variant of it.

## 1. The core abstraction: "one mutually-reachable network"

k3s (like all Kubernetes) assumes every node lives on **one private network that is mutually reachable in both directions, with stable addressing, and no NAT/firewall interference** in the middle.

- It is a *reachability* property, **not a topology property**: same LAN, routed subnets, or a WireGuard tunnel all satisfy it; two nodes on the same desk violate it if a firewall sits between them. Distance is irrelevant; dial-ability and address stability are everything.
- **If the assumption is false, the fix belongs at the network layer** — same LAN + static per-node IPs, or an overlay (Tailscale/WireGuard). Never by contorting how k3s advertises itself.
- NAT breaks it (asymmetric reachability). Roaming DHCP breaks it (address instability). Mutual firewalls break it. These are all network problems with network-layer answers.

## 2. Why a node must "find its own IP" at all

k3s is a distributed system: every process must be reachable by the other processes, and reachability requires a concrete address. Loopback (`127.0.0.1`) only reaches processes on the same host in the same network namespace — useless for anything crossing a boundary:

- other machines (multi-node peers, remote clients) need a routable address;
- pods live in separate network namespaces and can't use the host's loopback;
- the kernel is the only authority on the host's own addresses — k3s can't invent one, it must ask.

Crucially, the node IP is **not a local convenience — it is shared, stored state**. It gets written into etcd's raft log, the `Node` object, certificates, flannel's backend. Other components later act on the *stored copy*, not on the host's current reality. There is no "discovery" or "broadcast" in Kubernetes — everything is **advertise + register**: each component declares its address, others persist it, and the stored value becomes the source of truth.

## 3. Node IP selection: a precedence chain

k3s picks ONE advertise address, in order, first match wins:

1. explicit `--node-ip` / `--node-external-ip`
2. the IP of `--flannel-iface` — but that only pins the *interface*, not the address (an interface can hold many IPs)
3. the **kernel's default-route source** — what `ip route get <dest>` reports as `src` (the route table decides which of several interface IPs is "primary")
4. hostname → DNS resolution

On this machine: `ip route get 8.8.8.8` → `src 192.168.179.136`, which is why k3s chose `.179.136` over the also-present `.1.200`. In July, the same rule produced `.124` — the network (and its default route) changed between boots. **`--flannel-iface` only pins the card; the route table pins the identity.**

## 4. What the node IP gets baked into (advertise surfaces)

| Surface | Port | Notes |
|---|---|---|
| kube-apiserver `--advertise-address` | 6443 | *listen* on loopback, *advertise* where clients can reach — `--bind-address` vs `--advertise-address` are deliberately split |
| etcd client URL | 2379 | the address other members' apiservers would use; stored in membership record |
| **etcd peer URL** | 2380 | the load-bearing one — raft identity + reachability fused |
| kubelet `Node` registration | — | `InternalIP` used by scheduler, apiserver (`kubelet-preferred-address-types=InternalIP,...`), kubectl |
| flannel VTEP | — | other nodes' overlay endpoints |
| TLS SANs | — | the *only* self-healing surface (k3s regenerates certs when the IP changes) |

## 5. etcd membership: identity pinned at bootstrap

With `--cluster-init`, first boot creates member `strix-halo-f917b42f` (ID `9702c6794fa06d5e`) and writes its peer URL `https://<node-ip>:2380` **into the raft log itself**. Every later boot *recovers* identity from local data (`recovered/added member from store`), never from the host. The membership record and the raft log are **one atomic artifact**: you cannot keep the log and change the identity, because two members claiming one log = two instances of one state = split-brain by definition.

## 6. Identity vs. location: why address changes are explicit consensus ops

- **Identity is stable** (member ID, random, unforgeable in practice); **location is mutable** (peer URL).
- The cluster cannot distinguish "same node moved" from "clone / snapshot restore / impersonation" — those are exactly the scenarios where a second machine holds the same log. Auto-accepting a changed address would produce two live instances of one member: the condition consensus systems exist to prevent.
- Therefore every membership mutation — including a member's *own* address — is an explicit, quorum-committed append (`etcdctl member update`), never an automatic boot-time decision. The log is append-only: you can't rewrite history, only record "member X now lives at Z."
- The three exits from a membership/address mismatch map to the three legal resolutions:
  - **in-band explicit write** (`member update`) — the same announcement the node was already trying to make, issued once, deliberately;
  - **make the stored truth true again** (restore the old address) — no mutation needed;
  - **destroy the record** (`--cluster-reset`: "forget all peers, become sole member of a new cluster") — explicit consent to abandon identity + log.

## 7. Why it can't self-heal: "publish" is a write, not a broadcast

There is no announcement channel in etcd — no mDNS, no gossip. Telling the cluster anything, including "my address changed," means **committing a write to the raft log**, which requires the cluster to be healthy enough to commit — which is the very thing in question.

Observed in this incident: etcd *does* try to announce its new address (`failed to publish local member to cluster through raft ... ClientURLs:[https://192.168.179.136:2379]`), but every attempt fails with `etcdserver: too many requests` — the write path wedges, k3s's 5-second health-check loop hammers it harder, and the chicken-and-egg completes: to announce you must commit; to commit the cluster must be consistent; the announcement was supposed to fix the inconsistency. The server stays alive for reads (SERVING, defrag works) but never becomes ready.

## 8. Join semantics: one-way for agents, bidirectional for servers

- **Agents**: reachability from the agent to the join address (6443) is the whole requirement — the VIP is perfect for this. Conditions: token matches; join address must be in the server cert SANs (`--tls-san`).
- **Servers**: the front door must be reachable **and** the peer URLs (2380) of all servers must be mutually reachable in both directions — every server dials every other server's advertised peer URL for raft. The VIP only solves the front door; raft never uses it.
- **NAT failure mode** (joining via a public URL from a private subnet): the front door works (router forwards 6443 → VIP), then etcd fails in *both* directions — the new node can't dial existing members' private peer URLs (only 6443 is forwarded; and even a 2380 forward can reach only one internal host while peer URLs are per-member), and existing members can't dial the new node's advertised private IP (its router forwards nothing). Modern k3s adds new members as *learners* first (`max-learners: 1`), so the existing cluster keeps quorum while the new server hangs forever at etcd bootstrap. On older direct-add semantics, a 2-node cluster could lose quorum from a bad join attempt.
- **Why "just use public URLs everywhere" fails**: hairpin NAT (a node often can't reach its own public IP from inside its LAN), exposing 2379/2380 + cluster secrets to the internet, and needing a unique stable public address per node. That's rebuilding a VPN by hand, badly.
- **Agent asymmetry**: an agent behind NAT joining via public URL does join (one-way), but the reverse path breaks — the apiserver reaches the agent's kubelet at its `InternalIP` for `kubectl logs/exec`/metrics, which is unreachable → node may show Ready while exec/logs hang.
- **The fix for spread-out nodes is the network**: overlay (Tailscale/WireGuard) manufactures the "one private network" — mutually reachable both directions, stable addressing, no NAT — which is exactly what raft requires.

## 9. "Rejoin as new identity": why automatic is impossible, and the explicit path

A node with local etcd data is **resuming** an existing identity, not joining — "joining" is defined by the *absence* of local state (fresh member ID, catch-up replication from peers). But a new identity *is* a legitimate, documented operation — as **explicit maintenance**:

```
1. etcdctl member remove <member-id>      ← record intent: "X is gone, deliberately"
   (modern k3s also does this when you kubectl delete node <name>)
2. rm -rf /var/lib/rancher/k3s/server/db/etcd   ← otherwise it tries to resume X
3. k3s server --server https://<surviving-peer>:6443 --token <token>
   → added as fresh member Y → replicates the log from remaining peers → full member
```

It cannot be automatic, for three gates:

1. **Last-copy problem**: the local log may be the only surviving copy of the cluster's data. The node can't know whether peers survive (all nodes rebooted with changed IPs is indistinguishable from "only I am broken"). Auto-renunciation = auto-permission to destroy the last copy → permanent data loss.
2. **Crash vs. partition**: an isolated node can't tell "everyone else is dead" from "I'm partitioned while the rest keep serving." If renouncing identity were automatic, a partition would make the isolated node rejoin as new while the other side still holds the old member → same cluster ID, two memberships → fork (the one failure consensus is built to forbid). Only a human sees the whole picture.
3. **Zombie members**: if a node "joined fresh" every reboot *without* removing the old record, each reboot adds a member. Raft quorum = majority of *all recorded* members, so offline zombies inflate the required majority until live nodes can't reach it → whole cluster read-only. Explicit removal is what prevents accumulation.

**Single-member caveat** (this incident): remove + rejoin requires *surviving peers to catch up from*. With one member, removal destroys the cluster, the wipe destroys the only log copy, and there is nothing to rejoin to. Identity must be preserved; only the address is fixed. This is why for a single-member group, `member update` (or restoring the old address) is the *only* data-preserving path — "new identity" is not merely risky, it's guaranteed destruction.

**Bottom line**: identity is stable, location is mutable, and every location change is recorded in the log as an explicit, operator-acknowledged act. That's what keeps reboots free (nothing changed → resume), maintenance safe (remove → rejoin), and partitions/corruption impossible by construction.

## 10. keepalived VIP: the two-plane rule

The VIP (`192.168.1.200`) is the **client plane**; node IPs are the **cluster plane**. Never merged:

| Plane | Address | Role | Owner |
|---|---|---|---|
| Client | VIP `192.168.1.200` | API endpoint for agents/kubectl (`server: https://192.168.1.200:6443`) | keepalived (floats) |
| Cluster | each node's own IP | etcd peer/client URLs, flannel | each node, pinned |

etcd forbids duplicate member peer URLs (the VIP is a singleton — only one node holds it at a time), raft does its own leader election over direct member connections (no VIP failover — the VIP floating would re-point raft traffic at a machine that isn't that member), and etcd doesn't know keepalived exists. The VIP belongs in `--tls-san` and in agents' kubeconfigs — never in `--node-ip`/etcd. The current unit file already does this correctly.

## 11. The consolidated model

> k3s assumes every node lives on one mutually-reachable network, with stable addresses, no NAT/firewall interference. Node identity comes from the etcd raft log and is stable; the node's address is derived from that network and must be stable too. If the network can't provide it, change the network (same LAN, static IPs, or an overlay) — never how k3s advertises itself.

---

# Part II — The incident

## Evidence

- `systemctl status k3s` → `Active: activating (start)`; 252+ retries of the "not a member" check.
- `ip -4 addr show wlp195s0` → `192.168.179.136/24` (DHCP) + `192.168.1.200/24` (manual). No `.124` anywhere; `ping 192.168.1.124` fails.
- `ip route get 8.8.8.8` → `src 192.168.179.136` — the kernel's default-route source = the IP k3s chose (Rule 3).
- Jul 10 first-boot log: `Found ip 192.168.1.124 from iface wlp195s0` — cluster born with `.124` as node IP.
- etcd is alive: `grpc service status ... SERVING`, defrag runs; the write path is wedged (`failed to publish local member ... too many requests`).
- etcd knows **only one member**: `Found [strix-halo-f917b42f=https://192.168.1.124:2380]`.
- keepalived is running; unit has `--tls-san=192.168.1.200` (VIP, client plane — correct per Rule 10).
- NixOS host; k3s unit `/etc/systemd/system/k3s.service`: `ExecStart ... --cluster-init --flannel-iface=wlp195s0 --tls-san=192.168.1.200`; token at `/run/secrets/k3s-token`.

## Diagnosis chain

1. Reboot at 11:33; network changed: DHCP now gives `.179.136` (default route via `.179.37`), manual `.1.200` retained, old `.124` gone.
2. k3s precedence chain (Rule 3) → node IP = `.179.136` → etcd peer/client URLs computed as `.179.136`.
3. etcd recovers member from its own log: peer URL `.124:2380` (Rule 5) → mismatch → publish of new attributes fails, write path wedges (Rule 7) → k3s's IsMember check loops forever ("not a member").
4. Result: etcd + apiserver processes run, but k3s never signals ready — service permanently `activating`.

## Recovery options

All need root. No passwordless sudo on this box.

**Option A — update the stored member URL in-band (data-preserving, preferred):**

```bash
sudo /nix/store/5d6pxpv80k1m8l2yxb3111lqq4kh48np-k3s-1.35.7+k3s1/bin/k3s etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
  member list
# then
... member update 9702c6794fa06d5e --peer-urls=https://<pinned-node-ip>:2380
sudo systemctl restart k3s
```

Target the **pinned** address (Recommendations), not the transient DHCP address — done once, forever.

**Option B — restore the old address (data-preserving fallback):** re-add `192.168.1.124/24` on `wlp195s0` + `--node-ip=192.168.1.124`, restart. Makes the stored truth true again, no mutation needed; ties the node to a stale address.

**Option C — destroy & reset (data-wiping):** `k3s server --cluster-reset` ("forget all peers, become sole member of a new cluster"). Only if cluster data is disposable.

## Recommendations

1. **Pin the node IP** — add `--node-ip=192.168.1.200` (the machine's existing manual, persistent address; already the `--tls-san` VIP) or a per-node static/reserved address. Then `member update` targets that address once and never repeats. DHCP-derived node IPs are the root cause of this class of outage.
2. If nodes must roam networks: overlay (Tailscale/WireGuard) for a stable per-node address; keepalived VIP stays client-plane.
3. Never advertise the VIP as node IP / etcd identity (Rule 10).
4. Multi-server HA: per-node static IPs on the shared LAN, VIP for clients only; any single node can then be restarted or replaced (remove → wipe → rejoin, Rule 9) without ceremony.
5. Address stability is part of the abstraction: stable, unique, mutually reachable (Rule 1 + Part I §1).

## Open questions

- Is the cluster genuinely multi-server? etcd currently knows only this one member — other servers (implied by keepalived) are not in this etcd group.
- Which address to pin long-term: `192.168.1.200` (already present/manual) vs. restoring `192.168.1.124` vs. a new static per-node plan.
- Recovery timing (needs sudo access to run Option A/B).

# llama-server Router Idle Model Eviction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make idle llama-server router models release their VRAM after 30 minutes of inactivity, instead of staying resident indefinitely.

**Architecture:** Single-line config change in `dotfiles/llama-server/models.ini`, under the existing `[*]` section that already applies flags to every model preset (`flash-attn = true`). No Nix module changes — `sleep-idle-seconds` is a router-mode CLI flag that `models.ini` passes straight through, same path as `ctx-size`. Applied live via `systemctl restart llama-cpp-chat` (the service bind-mounts this file directly — see `docs/changes/2026-07-13-llama-server-models-preset-plan.md:153` — so no `nixos-rebuild` is required).

**Tech Stack:** llama.cpp (`llama-server`, router mode, local build `10063`/`7d56da7`), NixOS (`services.llama-server` from the `nixos-server` flake input), systemd.

---

## Context for the engineer

- Full background: `docs/issues/llamacpp-router-no-idle-eviction.md` and `docs/changes/2026-07-30-llamacpp-idle-eviction-requirement.md`.
- The router is `llama-cpp-chat.service` on host `strix-halo`, defined in `hosts/strix-halo.nix:25-36` (`services.llama-server.instances.chat`), listening on port `11434`.
- It reads `/etc/llama-server/models.ini`, which is a read-only bind mount of `dotfiles/llama-server/models.ini` (see `bindReadOnlyPaths` in `hosts/strix-halo.nix:30-33`). Editing the dotfiles file and restarting the service applies the change — you do **not** need `nixos-rebuild switch` for this change.
- `sleep-idle-seconds` unloads model weights/KV-cache from VRAM after N idle seconds but leaves the child subprocess alive with a ~600MiB residual GPU allocation (known upstream limitation, [llama.cpp#19379](https://github.com/ggml-org/llama.cpp/issues/19379), no fix available — see requirement doc). This plan does not attempt to fix that; a 30-minute timeout is still a large net win given every model here runs `ctx-size = 262144`.
- This host's GPU is an AMD Strix Halo APU. VRAM usage is read from `/sys/class/drm/card*/device/mem_info_vram_used` (bytes), no extra tooling needed.

## Task 1: Add idle timeout to models.ini

**Files:**
- Modify: `dotfiles/llama-server/models.ini:1-4`

- [ ] **Step 1: Add `sleep-idle-seconds` under `[*]`**

Current file starts:

```ini
version = 1

[*]
flash-attn = true
```

Change the `[*]` section to:

```ini
version = 1

[*]
flash-attn = true
sleep-idle-seconds = 1800
```

- [ ] **Step 2: Confirm no other section overrides it**

```bash
grep -n "sleep-idle-seconds" dotfiles/llama-server/models.ini
```

Expected: exactly one match, under `[*]` (the line just added). No per-model `[SectionName]` block should define its own `sleep-idle-seconds` — if one does, remove it so all models share the same 30-minute timeout (per the requirement doc's "out of scope: per-model overrides").

- [ ] **Step 3: Commit**

```bash
git add dotfiles/llama-server/models.ini
git commit -m "llama-server: sleep idle models after 30 minutes to free VRAM"
```

## Task 2: Apply and verify on strix-halo

This task runs on the `strix-halo` host itself (not in the worktree) since it exercises a live systemd service and real GPU memory. If you're executing this plan from an isolated worktree, do Task 2 from the actual host checkout after Task 1 is merged/pulled there.

**Files:** none (operational verification only)

- [ ] **Step 1: Restart the service to pick up the new config**

```bash
sudo systemctl restart llama-cpp-chat
sudo systemctl status llama-cpp-chat --no-pager
```

Expected: `active (running)`, recent start timestamp.

- [ ] **Step 2: Trigger one model load**

```bash
curl -s http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen3.6-27B","messages":[{"role":"user","content":"hi"}],"max_tokens":8}' \
  | head -c 300
```

Expected: a JSON completion response (non-error). This forces the router to spawn/load the `Qwen3.6-27B` child process.

- [ ] **Step 3: Record VRAM usage right after the request**

```bash
cat /sys/class/drm/card*/device/mem_info_vram_used
ps -eo pid,etime,cmd | grep '[Q]wen3.6-27B'
```

Expected: non-trivial VRAM usage (multi-GB, this model + its `ctx-size=262144` KV cache), and one running `llama-server` child process for `Qwen3.6-27B` with a fresh `etime`.

- [ ] **Step 4: Wait past the idle timeout and re-check**

Wait at least 1800 seconds (30 minutes) without sending any further requests to `Qwen3.6-27B`, then:

```bash
cat /sys/class/drm/card*/device/mem_info_vram_used
ps -eo pid,etime,cmd | grep '[Q]wen3.6-27B'
```

Expected: VRAM usage from step 3 has dropped substantially (the model's weights/KV-cache were released). The `llama-server` child process for `Qwen3.6-27B` may still be listed in `ps` (that's the documented ~600MiB-residual limitation, not a failure) — the pass criterion is the VRAM drop, not process disappearance.

- [ ] **Step 5: Note completion**

No commit needed for this task (verification only). If step 4's VRAM drop doesn't happen, treat it as a bug against this change and re-open `docs/issues/llamacpp-router-no-idle-eviction.md` rather than closing it.

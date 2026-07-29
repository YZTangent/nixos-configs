# llama-server router idle model eviction — Requirement

**Status:** approved
**Related issue:** `docs/issues/llamacpp-router-no-idle-eviction.md`
**Related ADRs:** none

## Problem

`services.llama-server` instance `chat` (`hosts/strix-halo.nix:25-36`) runs llama-server in router mode against `dotfiles/llama-server/models.ini`. Every model entry sets `ctx-size = 262144` and full GPU offload. Once a model is first requested, its child process stays resident indefinitely — no idle timeout is configured — so VRAM usage only grows as more models get touched over a session. This contributed to a VRAM-exhaustion crash (see `docs/issues/niri-oom-crash-on-amdgpu-cs-rejection.md`).

## Fix

Set `sleep-idle-seconds = 1800` under the `[*]` section of `dotfiles/llama-server/models.ini`, so every model preset inherits a 30-minute idle timeout (matches the pattern already used for `flash-attn = true` under `[*]`).

`sleep-idle-seconds` is a router-mode CLI flag (`llama-server --help`) that models.ini's `[*]`/per-model sections pass straight through, the same path `ctx-size`/`flash-attn` already use — no Nix module change needed, since this flag isn't exposed as a typed `services.llama-server` option.

## Known limitation (not fixed by this change)

Upstream llama.cpp issue [#19379](https://github.com/ggml-org/llama.cpp/issues/19379): in router mode, `sleep-idle-seconds` unloads model weights/KV-cache from VRAM but the child subprocess stays alive holding a residual ~600MiB GPU allocation. A proposed fix (`--stop-idle-seconds`, full subprocess termination) was **never merged** — closed 2026-02-06 by a maintainer as out of scope for the server itself. There is currently no flag-based way to fully release that residual allocation; reclaiming it would require externally restarting the subprocess (e.g. a systemd timer), which is out of scope for this change.

Given every model here runs `ctx-size = 262144`, the KV-cache/weights VRAM this change does reclaim is the dominant cost — the 30-minute timeout is the fix worth having now.

## Out of scope

- Upgrading llama.cpp to chase a `stop-idle-seconds`-equivalent (doesn't exist upstream).
- Per-model idle timeout overrides (all models get the same 1800s under `[*]`; can be overridden per-section later if needed).
- Any change to `services.llama-server` Nix module options.

## Verification

Deployed NixOS host, so verification is: rebuild/deploy, restart `llama-cpp-chat.service`, request a model, then after >1800s of no requests confirm (via `ps`/GPU VRAM query) that the model's VRAM usage drops — accepting the known ~600MiB residual per idle subprocess as expected, not a failure.

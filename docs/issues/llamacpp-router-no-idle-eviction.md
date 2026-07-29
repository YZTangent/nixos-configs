# llama-server router never evicts idle models

**Status:** unresolved, no fix applied

## Summary

The llama-server router (`services.llama-cpp-chat`, invoked with `--models-preset /etc/llama-server/models.ini`) never unloads idle models. Once a model is first requested, its child `llama-server` process stays resident indefinitely, holding its full VRAM footprint — contributing to the VRAM exhaustion that crashed niri (see [niri-oom-crash-on-amdgpu-cs-rejection.md](niri-oom-crash-on-amdgpu-cs-rejection.md)).

## Evidence

- `ps` at crash time (2026-07-28 23:36):
  - `Qwen3.6-35B` server (pid 5057): running since 2026-07-27 08:20 (1d16h+ uptime)
  - `Qwen3.6-27B` server (pid 70296): running since 2026-07-27 22:08 (1d02h+ uptime)
  - Both alive and resident simultaneously, despite only the 35B actively handling the request (`proxy_reques: proxying request to model Qwen3.6-35B on port 33065`) that triggered the crash — "active" (processing) and "loaded" (resident in VRAM) are different things here.
- `llama-server --help` exposes:
  ```
  --sleep-idle-seconds SECONDS   number of seconds of idleness after which the server will sleep
  ```
  Supported by this build, but unused anywhere in this config.
- `dotfiles/llama-server/models.ini`: no `sleep-idle-seconds` set under `[*]` or any per-model section.
- `llama-cpp-chat.service` `ExecStart` also doesn't pass it:
  ```
  llama-server --models-preset /etc/llama-server/models.ini --host 0.0.0.0 --port 11434 -ngl 999 --no-mmap
  ```
- Every model in `models.ini` is configured with `ctx-size = 262144` and full GPU offload (`-ngl 999`), so each resident model — even idle — holds a very large KV-cache-capable footprint in VRAM.

## Why this matters

Idle models accumulate VRAM usage over the life of the session rather than releasing it. Combined with the fixed ~64 GiB VRAM carveout on this Strix Halo APU (see companion issue for the VRAM/GTT/system-RAM breakdown), this steadily eats the headroom other GPU clients (the compositor, browser, etc.) need.

## Possible fix (not applied)

Add `sleep-idle-seconds = <N>` under `[*]` in `dotfiles/llama-server/models.ini` so idle model servers sleep/release GPU memory after N seconds of inactivity. Pick N to match actual model-switching cadence (e.g. 600–1800s).

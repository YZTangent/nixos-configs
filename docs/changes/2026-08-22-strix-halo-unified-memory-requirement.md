# Strix Halo unified memory + IOMMU-off — Requirement

**Status:** pending review
**Related issue:** `docs/issues/niri-oom-crash-on-amdgpu-cs-rejection.md` (context)
**Related ADRs:** none (proposed: ADR for `amd_iommu=off` tradeoff)
**Source:** [kyuz0/amd-strix-halo-toolboxes #host-configuration](https://github.com/kyuz0/amd-strix-halo-toolboxes#host-configuration)

## Problem

`hosts/strix-halo.nix` runs llama.cpp inference (Vulkan/radv) on the Radeon 8060S,
but the machine's GPU memory strategy differs from the upstream-tested one:

- BIOS currently carves out **64 GiB as dedicated VRAM** — permanently invisible
  to the CPU, whether the GPU uses it or not. The OS sees only 62.4 GiB of the
  128 GiB installed.
- No IOMMU/GTT tuning: `amd_iommu` left on (per-DMA translation overhead), GTT at
  driver default (31.2 GiB) instead of being capped to the available RAM.
- The rigid carve-out contributed to the niri crash in
  `docs/issues/niri-oom-crash-on-amdgpu-cs-rejection.md` (amdgpu CS rejection at
  96% VRAM — scanout buffers had nowhere to go).

## Fix

Switch to the upstream-tested **unified memory** strategy:

1. **BIOS (manual, out of band):** set "GPU memory" allocation from 64 GiB to
   **512 MiB** (minimum). This is the only BIOS change; done by the user.
2. **NixOS (`hardware/strix-halo.nix`, new module, imported from
   `hosts/strix-halo.nix`):**
   ```nix
   boot.kernelParams = [
     "amd_iommu=off"            # disable AMD IOMMU: faster unified-memory DMA
     "amdgpu.gttsize=126976"    # iGPU GTT cap: 126976 MiB = 124 GiB
     "ttm.pages_limit=32505856" # pinned-page cap: 32505856 × 4 KiB = 124 GiB
   ];
   ```
   `gttsize` and `pages_limit` are the two layers of the same 124 GiB budget
   (driver-side GTT allocation vs kernel-side pin accounting); they must agree.
   The iGPU claims system RAM on demand — the cap is a ceiling, not a
   reservation, so the CPU sees ~127.5 GiB when the GPU is idle.

## Verified state

- Kernel 6.18.39 (≥ 6.18.4, the gfx1151 stability threshold) — no pinning needed.
- Firmware 20260110 (the version recommended upstream; the known-bad 20251125
  build is avoided). No pinning: user runs radv, the 20251125 regression was
  ROCm-specific. Documented in module comments for future reference.
- Vulkan backend confirmed active in the running `llama-cpp-chat.service`
  (journal: `Vulkan0: AMD Radeon 8060S (RADV STRIX_HALO)`, live
  `llama-cli --list-devices` shows the same). No backend changes in scope.
- `nix eval .#nixosConfigurations.strix-halo.config.boot.kernelParams` resolves to
  `["amd_iommu=off" "amdgpu.gttsize=126976" "ttm.pages_limit=32505856" ...]`.
- `nixos-rebuild build --flake .#strix-halo` succeeds.

## Sequencing (user action)

1. `sudo nixos-rebuild boot --flake .#strix-halo` from `~/.home` (installs the
   new GRUB entries; does not switch the running system).
2. Enter BIOS, change GPU memory 64 GiB → 512 MiB.
3. Reboot. Verify: `free -h` shows ~127 GiB, `llama-cli --list-devices` shows
   ~124 GiB, `cat /sys/class/drm/card1/device/mem_info_vram_total` ≈ 512 MiB.

## Out of scope

- TuneD GPU workload watcher (`systemd/gpu-workload-watch/`) — separate follow-up.
- Toolboxes/containers — the native `services.llama-server` path is kept.
- Firmware pinning (see Verified state).
- Headroom tuning: the 124 GiB cap leaves ~4 GiB for the OS at the extreme; if
  huge-model runs ever starve the desktop, switch to ~110 GiB
  (`gttsize=112640`, `pages_limit=28835840`). Not defaulting to it now.

# Logitech mouse cursor stutter (USB dongle)

**Status:** unresolved, root cause not identified

## Symptom

Severe, recurring lag spikes affecting *only* the mouse cursor — the cursor stutters like crazy while everything else on screen is unaffected. Spikes come in bursts lasting roughly hundreds of ms to a few seconds each, with no obvious trigger.

Mouse: Logitech, connected via USB receiver dongle (`046D:C548`, "USB Receiver" — Bolt/Unifying-class).

## Environment notes

- Two Logitech `046D:C548` receivers are plugged in simultaneously, on two different USB controllers:
  - `1-1` on PCI `0000:c7:00.4`
  - `3-2` on PCI `0000:c9:00.0`
  - Not yet confirmed whether this is intentional (e.g. separate keyboard + mouse receivers) or a leftover second dongle — worth double-checking.
- No USB errors, resets, or autosuspend activity found in dmesg/sysfs for either receiver over the observation window (`power/control: on`, `runtime_status: active`, 0 suspended time) — the USB layer itself looks clean.

## Hypotheses investigated

### 1. amdgpu DPM clock ramp-up — ruled out
GPU was observed idling at 641MHz (of a 3-state table: 600/641/2900MHz) with `gpu_busy_percent` ~1%, `power_dpm_force_performance_level` = `auto`. Theory: cursor movement is the only thing generating light GPU load when the desktop is otherwise idle, and each move triggers a clock-ramp transition whose latency shows up as cursor-only stutter.

**Ruled out**: a clock transition is a one-shot, sub-tens-of-ms event. It doesn't explain repeating bursts lasting hundreds of ms to multiple seconds.

### 2. GPU queue contention with llama.cpp inference — ruled out
Both local llama-server model instances (Qwen3.6-35B, Qwen3.6-27B) render via the same Vulkan/RADV device niri uses for compositing, with no isolation/priority between compositor and compute submissions. Individual inference requests were observed taking hundreds of ms to several seconds (e.g. one logged at 7140ms total) — a plausible duration match.

**Ruled out by user confirmation**: stutter has been observed while neither model was handling any request. Only two consumers of the local models exist and neither was invoked during some observed spikes.

### 3. mt7925e WiFi power-save (shared platform-level stall) — slim, unconfirmed
See [`intermittent-network-stalls/investigation-log.md`](intermittent-network-stalls/investigation-log.md) — a separate, still-open investigation into intermittent WiFi stalls with a similar bursty/unpredictable signature. USB HID input and the WiFi stack don't share a code path, so there's no direct mechanism linking them. The only honest framing is: *if* a shared platform-level event (see #4) is stalling the whole system briefly, both would show up as independent symptoms — this has not been demonstrated, only noted as a coincidence worth tracking.

### 4. SMI storms (System Management Interrupts) — proposed, not yet investigated
Firmware-level interrupts (thermal management, EC communication, USB legacy keyboard emulation, etc.) run at a CPU privilege level above the OS and can briefly freeze every core for tens to hundreds of ms. Invisible to normal OS tools (`/proc/interrupts` doesn't see them). Classic reported symptom is exactly "mouse stutters for no reason," since cursor movement is the one thing that demands continuous scheduling when everything else is static/idle — this would also explain why *only* the cursor visibly stutters.

**Not yet checked.** Normal detection method is `turbostat` (reports CPU time unaccounted for by IRQs) — not installed on this host. Alternative: a small high-resolution timestamp-gap logger that flags any wall-clock jump beyond the expected tick interval, which would detect a whole-system stall directly regardless of cause, and could be correlated against felt stutter timing.

## Next steps (not yet started)

1. Confirm whether both Logitech receivers are intentional.
2. Install `turbostat` (or write the timestamp-gap logger) and capture data during a live stutter to check for SMI activity.
3. If SMI is confirmed or ruled out, revisit the WiFi shared-cause hypothesis.

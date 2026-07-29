# niri aborts instead of degrading gracefully on amdgpu CS rejection

**Status:** unresolved, no fix applied

## Summary

niri crashes (SIGABRT) instead of degrading gracefully when the amdgpu kernel driver rejects a GPU command submission due to VRAM exhaustion. A memory-pressure spike from an *unrelated* process was able to kill the entire desktop session.

## Timeline (2026-07-28 23:36:50, boot `156093ff63f44ec5a2e5e5706792cc10`)

1. `journalctl -k`:
   ```
   amdgpu 0000:c7:00.0: amdgpu: [drm] *ERROR* Not enough memory for command submission!
   ```
   (×3, immediately preceding the abort)
2. niri log: `amdgpu: The CS has been rejected, see dmesg for more information (-12)`
3. `systemd-coredump`: `Process 4821 (niri) of user 1000 terminated abnormally with signal 6/ABRT`
4. `coredumpctl info 4821` backtrace:
   ```
   smithay::backend::egl::fence::EGLFence::create
   → smithay::backend::renderer::gles::GlesFrame::finish_internal
   → smithay::backend::renderer::gles::GlesFrame::finish
   → smithay::backend::renderer::multigpu::MultiFrame::finish_internal
   → smithay::backend::renderer::damage::OutputDamageTracker::render_output
   → smithay::backend::drm::compositor::DrmCompositor::render_frame
   → niri::backend::tty::Tty::render
   → niri::niri::Niri::redraw_queued_outputs
   → niri::niri::State::refresh_and_flush_clients
   ```
5. Cascade — once the compositor died, every Wayland/X11 client lost its display connection (collateral, not independent crashes):
   - Xwayland: `mod.x11-bell: X11 display (:1024) has encountered a fatal I/O error`
   - Zen browser: SIGSEGV (coredump present)
   - Telegram (`.Telegram-wrapped`): SIGABRT (coredump present)
6. GDM auto-restarted the session at 23:36:56 — same boot, no reboot occurred.

## Root trigger

VRAM (the fixed ~64 GiB BIOS carveout on this Strix Halo APU — see [llamacpp-router-no-idle-eviction.md](llamacpp-router-no-idle-eviction.md)) was at ~96% used at crash time, driven by two resident LLM model server processes. niri's scanout/render buffer allocation for that frame had nowhere to go.

Specifically a **VRAM**-domain failure, not GTT or general system RAM: amdgpu KMS scanout buffers must be VRAM-backed (GTT cannot back a display framebuffer in this driver stack), so niri's render-frame allocation could only fail against the VRAM pool.

## Why this matters

A transient GPU memory pressure spike from an unrelated process (LLM inference, in this case) should not be able to kill the entire desktop session. A well-behaved compositor should drop the frame, retry, or log and continue — not abort the process.

## Possible directions (not decided)

- File upstream against niri/smithay for graceful handling of a rejected command submission (log + skip frame, rather than abort).
- Locally mitigate by capping VRAM pressure so this scenario becomes rare (see companion issue on llama.cpp idle eviction).

# Requirement: Switch llama-server to models-preset INI file

## Summary

Replace `--models-dir` with `--models-preset` in the llama-server router configuration on strix-halo. Models are sourced from `~/.lmstudio/models/` (LM Studio's model directory). The INI file lives in the dotfiles repo and is bind-mounted live into the service namespace — edits take effect on service restart without a `nixos-rebuild`.

## Context

- ADR 0004 established llama-server as a host systemd service in router mode
- The current config uses `--models-dir /var/lib/llama-models` to auto-discover GGUFs
- llama-server b9608 supports `--models-preset PATH`: an INI file where each `[section]` defines a named model with explicit paths and per-model parameters
- The `llama` system user cannot traverse `/home/yztangent/` (mode 700), so the service cannot directly read `~/.lmstudio/` or `~/.home/dotfiles/`
- systemd `BindReadOnlyPaths` resolves this: mounts are set up as root before the service drops to the `llama` user

## Changes

### 1. nixos-server module — `services/llama-server.nix`

Add two options to `instanceModule`:

```nix
modelsPreset = lib.mkOption {
  type = lib.types.nullOr lib.types.str;
  default = null;
  description = "Path to INI preset file for router mode. When set, replaces --models-dir.";
};

bindReadOnlyPaths = lib.mkOption {
  type = lib.types.listOf lib.types.str;
  default = [];
  description = "src:dst bind-mounts (read-only) set up by systemd as root in the service namespace, for reaching paths the llama user cannot traverse directly.";
};
```

Make `ExecStart` conditional on `modelsPreset`:

```nix
ExecStart = "${pkgs.llama-cpp-vulkan}/bin/llama-server "
          + lib.concatStringsSep " " (
              (if inst.modelsPreset != null
               then [ "--models-preset" inst.modelsPreset ]
               else [ "--models-dir" inst.modelsDir ])
              ++ [ "--host" inst.host "--port" (toString inst.port) ]
              ++ inst.extraArgs);
```

Add to `serviceConfig`:

```nix
BindReadOnlyPaths = inst.bindReadOnlyPaths;
```

### 2. Dotfiles — `dotfiles/llama-server/models.ini` (new file)

Tracked in the `.home` repo. Bind-mounted at `/etc/llama-server/` inside the service namespace.

- Global `[*]`: flash-attn only (GPU layer count and mmap stay as server-level CLI args)
- Per-model: explicit paths under `/var/lib/llama-lmstudio/` (the bind-mount destination for `~/.lmstudio/models/`), context size set to model maximum
- MiMo-V2.5 capped at 256K (training max is 1M but would OOM on this iGPU)
- Qwen3-Coder-Next excluded — shards 1 and 2 are still downloading

```ini
version = 1

[*]
flash-attn = true

[MiMo-V2.5]
model    = /var/lib/llama-lmstudio/unsloth/MiMo-V2.5-GGUF/MiMo-V2.5-UD-Q2_K_XL-00001-of-00004.gguf
ctx-size = 262144

[gemma-4-26B-Q8]
model    = /var/lib/llama-lmstudio/lmstudio-community/gemma-4-26B-A4B-it-GGUF/gemma-4-26B-A4B-it-Q8_0.gguf
mmproj   = /var/lib/llama-lmstudio/lmstudio-community/gemma-4-26B-A4B-it-GGUF/mmproj-gemma-4-26B-A4B-it-BF16.gguf
ctx-size = 262144

[gemma-4-26B-QAT]
model    = /var/lib/llama-lmstudio/lmstudio-community/gemma-4-26B-A4B-it-QAT-GGUF/gemma-4-26B-A4B-it-QAT-Q4_0.gguf
mmproj   = /var/lib/llama-lmstudio/lmstudio-community/gemma-4-26B-A4B-it-QAT-GGUF/mmproj-gemma-4-26B-A4B-it-QAT-BF16.gguf
ctx-size = 262144

[Qwen3.6-35B]
model    = /var/lib/llama-lmstudio/lmstudio-community/Qwen3.6-35B-A3B-GGUF/Qwen3.6-35B-A3B-Q8_0.gguf
mmproj   = /var/lib/llama-lmstudio/lmstudio-community/Qwen3.6-35B-A3B-GGUF/mmproj-Qwen3.6-35B-A3B-BF16.gguf
ctx-size = 262144

[MiniCPM5-1B]
model    = /var/lib/llama-lmstudio/openbmb/MiniCPM5-1B-GGUF/MiniCPM5-1B-F16.gguf
ctx-size = 131072
```

### 3. strix-halo.nix — update `instances.chat`

```nix
instances.chat = {
  port = 11434;
  modelsPreset = "/etc/llama-server/models.ini";
  bindReadOnlyPaths = [
    "/home/yztangent/.home/dotfiles/llama-server:/etc/llama-server"
    "/home/yztangent/.lmstudio/models:/var/lib/llama-lmstudio"
  ];
  extraArgs = [ "-ngl" "999" "--no-mmap" ];
};
```

Remove the `systemd.tmpfiles.rules` block that created `/var/lib/llama-models` — no longer needed.

## Live edit workflow

After deploy: edit `dotfiles/llama-server/models.ini` → `sudo systemctl restart llama-cpp-chat`. No `nixos-rebuild` needed.

## Out of scope

- Qwen3-Coder-Next — add to `models.ini` manually once the download completes
- Deployment (flake lock update, `nixos-rebuild switch`) — done by the operator

## Verification

```sh
systemctl status llama-cpp-chat
curl http://localhost:11434/v1/models
curl http://localhost:11434/v1/chat/completions \
  -d '{"model":"MiniCPM5-1B","messages":[{"role":"user","content":"hi"}]}'
```

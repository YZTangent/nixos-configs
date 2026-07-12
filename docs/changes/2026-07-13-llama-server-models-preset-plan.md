# llama-server models-preset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Switch the llama-server NixOS module from `--models-dir` to `--models-preset`, expose user-owned paths to the service via `BindReadOnlyPaths`, and wire up a live-editable `models.ini` in the dotfiles repo.

**Architecture:** Two-repo change. The nixos-server module gains `modelsPreset` and `bindReadOnlyPaths` per-instance options. strix-halo.nix uses them to bind-mount `~/.home/dotfiles/llama-server/` and `~/.lmstudio/models/` into the service namespace, then point `--models-preset` at `/etc/llama-server/models.ini` inside that namespace.

**Tech Stack:** NixOS modules (lib.types, systemd serviceConfig), llama-server b9608 (`--models-preset`, `BindReadOnlyPaths`), INI preset format

---

> **Important:** `.home` has uncommitted changes — never `git reset`, `git checkout --`, or `git restore` in that repo. Stage and commit only the specific files listed in each task.

---

### Task 1: Add `modelsPreset` and `bindReadOnlyPaths` options to the nixos-server module

**Repo:** `/home/yztangent/code/nixos-server`

**Files:**
- Modify: `services/llama-server.nix`

- [ ] **Step 1: Add `modelsPreset` option to `instanceModule`**

In `services/llama-server.nix`, inside the `instanceModule` options block (after the existing `modelsDir` option), add:

```nix
modelsPreset = lib.mkOption {
  type = lib.types.nullOr lib.types.str;
  default = null;
  description = "Path to INI preset file for router mode. When set, replaces --models-dir.";
};
```

- [ ] **Step 2: Add `bindReadOnlyPaths` option to `instanceModule`**

In the same options block, add after `modelsPreset`:

```nix
bindReadOnlyPaths = lib.mkOption {
  type = lib.types.listOf lib.types.str;
  default = [];
  description = "src:dst bind-mounts (read-only) set up by systemd as root in the service namespace, for reaching paths the service user cannot traverse directly (see ADR-0008).";
};
```

- [ ] **Step 3: Make ExecStart conditional on `modelsPreset`**

Replace the current `ExecStart` line in `systemd.services`:

```nix
# Before:
ExecStart = "${pkgs.llama-cpp-vulkan}/bin/llama-server "
          + lib.concatStringsSep " " ([
              "--models-dir" inst.modelsDir
              "--host" inst.host
              "--port" (toString inst.port)
            ] ++ inst.extraArgs);

# After:
ExecStart = "${pkgs.llama-cpp-vulkan}/bin/llama-server "
          + lib.concatStringsSep " " (
              (if inst.modelsPreset != null
               then [ "--models-preset" inst.modelsPreset ]
               else [ "--models-dir" inst.modelsDir ])
              ++ [ "--host" inst.host "--port" (toString inst.port) ]
              ++ inst.extraArgs);
```

- [ ] **Step 4: Add `BindReadOnlyPaths` to serviceConfig**

In the `serviceConfig` attrset, add after `ReadWritePaths`:

```nix
BindReadOnlyPaths = inst.bindReadOnlyPaths;
```

- [ ] **Step 5: Verify the module evaluates**

```bash
cd /home/yztangent/code/nixos-server
nix eval --file services/llama-server.nix 2>&1 | head -20
```

Expected: no errors (returns a lambda or attrset, not an error trace). If the file isn't directly eval-able as a standalone, skip — full eval happens in Task 3 Step 1.

- [ ] **Step 6: Commit**

```bash
cd /home/yztangent/code/nixos-server
git add services/llama-server.nix docs/adr/0008-bind-read-only-paths-for-user-files-in-system-services.md docs/adr/0004-llama-cpp-as-host-systemd-service.md
git commit -m "feat(llama-server): add modelsPreset and bindReadOnlyPaths instance options

- modelsPreset (nullOr str): when set, passes --models-preset instead of --models-dir
- bindReadOnlyPaths (listOf str): src:dst bind-mounts set up as root before service drops to unprivileged user, enabling access to home-directory files (see ADR-0008)
- ADR-0008: document BindReadOnlyPaths pattern for user-owned files in system services
- ADR-0004: update to reflect --models-preset replacing --models-dir
```

---

### Task 2: Create `dotfiles/llama-server/models.ini`

**Repo:** `/home/yztangent/.home`

**Files:**
- Create: `dotfiles/llama-server/models.ini`

- [ ] **Step 1: Create the directory and file**

Create `dotfiles/llama-server/models.ini` with the following content. Model paths use `/var/lib/llama-lmstudio/` — the bind-mount destination for `~/.lmstudio/models/`. MiMo capped at 256K (training max is 1M, would OOM on the Radeon 8060S iGPU). Qwen3-Coder-Next omitted (shards still downloading).

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

- [ ] **Step 2: Commit (only these files)**

```bash
cd /home/yztangent/.home
git add dotfiles/llama-server/models.ini docs/changes/2026-07-13-llama-server-models-preset-plan.md docs/changes/2026-07-13-llama-server-models-preset-requirement.md
git commit -m "feat: add llama-server models.ini preset

Lists all current LM Studio models with explicit paths and max context sizes.
Bind-mounted live into the llama-cpp-chat service namespace at /etc/llama-server/.
Edit this file and restart llama-cpp-chat to apply changes without nixos-rebuild.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Update `strix-halo.nix` to use the new options

**Repo:** `/home/yztangent/.home`

**Files:**
- Modify: `hosts/strix-halo.nix`
- Modify: `docs/changes/2026-07-13-llama-server-models-preset-requirement.md` (already exists — commit alongside)

- [ ] **Step 1: Update the `instances.chat` block**

In `hosts/strix-halo.nix`, replace:

```nix
services.llama-server = {
  enable = true;
  instances.chat = {
    port = 11434;
    modelsDir = "/var/lib/llama-models";
    extraArgs = [ "-ngl" "999" "--models-autoload" "-fa" "1" "--no-mmap" ];
  };
};
```

With:

```nix
services.llama-server = {
  enable = true;
  instances.chat = {
    port = 11434;
    modelsPreset = "/etc/llama-server/models.ini";
    bindReadOnlyPaths = [
      "/home/yztangent/.home/dotfiles/llama-server:/etc/llama-server"
      "/home/yztangent/.lmstudio/models:/var/lib/llama-lmstudio"
    ];
    extraArgs = [ "-ngl" "999" "--no-mmap" ];
  };
};
```

- [ ] **Step 2: Remove the `systemd.tmpfiles.rules` block**

Remove this block entirely — the `/var/lib/llama-models` directory is no longer used:

```nix
systemd.tmpfiles.rules = [
  # Model directory for llama-cpp and LM-Studio
  "d /var/lib/llama-models 2775 llama users - -"
];
```

- [ ] **Step 3: Verify nix evaluation**

```bash
cd /home/yztangent/.home
nix eval .#nixosConfigurations.strix-halo.config.services.llama-server
```

Expected: prints the resolved llama-server config attrset without errors. If the nixos-server flake.lock hasn't been updated yet to include the Task 1 commit, this will fail with a module option error — that's expected; the operator runs `nix flake update nixos-server` before deploying.

- [ ] **Step 4: Commit (only strix-halo.nix and the requirement doc)**

```bash
cd /home/yztangent/.home
git add hosts/strix-halo.nix
git commit -m "feat(strix-halo): switch llama-server to models-preset INI file

- Replace --models-dir with --models-preset pointing to /etc/llama-server/models.ini
- Bind-mount ~/.home/dotfiles/llama-server -> /etc/llama-server (live config)
- Bind-mount ~/.lmstudio/models -> /var/lib/llama-lmstudio (model files)
- Remove extraArgs GPU flags that moved to INI [*] section (flash-attn)
- Remove tmpfiles rule for /var/lib/llama-models (no longer needed)

Operator: run 'nix flake update nixos-server && sudo nixos-rebuild switch --flake .#strix-halo'
```

---

## Post-deploy verification (operator)

After `nix flake update nixos-server && sudo nixos-rebuild switch --flake .#strix-halo`:

```bash
# Service started cleanly
systemctl status llama-cpp-chat

# Models registered
curl http://localhost:11434/v1/models | jq '.data[].id'

# Route to a model by name
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"MiniCPM5-1B","messages":[{"role":"user","content":"hi"}]}'
```

## Live edit workflow

```bash
# Edit the model list
$EDITOR ~/.home/dotfiles/llama-server/models.ini

# Apply without rebuilding
sudo systemctl restart llama-cpp-chat
```

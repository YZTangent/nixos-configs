# Replace Hermes Gateway with Hermes Agent

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the custom `hermes-gateway` NixOS module from `nixos-server` with the official `hermes-agent` module from `github:NousResearch/hermes-agent`.

**Architecture:** Three-file changes plus two new files: add a flake input, recreate `.sops.yaml`, create a sops-nix-encrypted YAML secrets file for the Telegram bot token, add a `sops.secrets` declaration in `strix-halo.nix` wired via `config.sops.secrets."hermes-env".path`, then swap the module import and configuration block. No interactive CLI config — everything declarative.

**Tech Stack:** Nix flakes, NixOS modules, sops-nix, Docker.

**Official docs:** <https://hermes-agent.nousresearch.com/docs/getting-started/nix-setup>

---

### Task 1: Add `hermes-agent` flake input to `flake.nix`

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Add the `hermes-agent` input**

Add this block inside the `inputs` attribute set, after the existing `nixos-server` entry:

```nix
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

- [ ] **Step 2: Add `hermes-agent` to the outputs destructuring**

Change the `outputs` parameter destructuring from:

```nix
  outputs = { self, nixpkgs, home-manager, darwin, nixos-server, sops-nix, ... }@inputs: {
```

to:

```nix
  outputs = { self, nixpkgs, home-manager, darwin, nixos-server, hermes-agent, sops-nix, ... }@inputs: {
```

- [ ] **Step 3: Commit**

```bash
git add flake.nix
git commit -m "flake: add hermes-agent input"
```

---

### Task 2: Create sops-nix-encrypted YAML secrets file for hermes

**Files:**
- Create: `.sops.yaml`
- Create: `secrets/strix-halo-hermes.yaml` (sops-encrypted)

- [ ] **Step 1: Create or recreate `.sops.yaml`**

The old `.sops.yaml` is gone. Create a new one at the repo root:

```yaml
creation_rules:
  - path_regex: secrets/.*\.yaml$
    age: age1zjc86jcwcfsd69wnu5lwakdu89m22796y24qgv5glr9ys745r59smgv374
```

Verify the age key matches `/home/yztangent/.config/sops/age/keys.txt` (run `age-keygen -y /home/yztangent/.config/sops/age/keys.txt` to print the public key).

- [ ] **Step 2: Create the plaintext YAML file**

Extract the Telegram bot token from `/home/yztangent/.hermes/config.yaml`, then create:

```bash
mkdir -p secrets
cat > /tmp/strix-halo-hermes.yaml << 'EOF'
hermes-env: |
    TELEGRAM_BOT_TOKEN=<token_from_old_config.yaml>
EOF
chmod 600 /tmp/strix-halo-hermes.yaml
```

- [ ] **Step 3: Encrypt with sops**

```bash
sops --encrypt \
  --age age1zjc86jcwcfsd69wnu5lwakdu89m22796y24qgv5glr9ys745r59smgv374 \
  /tmp/strix-halo-hermes.yaml > secrets/strix-halo-hermes.yaml
```

Verify the output contains `ENC[AES256_GCM,` values (the `hermes-env` key's value is encrypted).

- [ ] **Step 4: Commit**

```bash
git add .sops.yaml secrets/strix-halo-hermes.yaml
git commit -m "secrets: add hermes bot token via sops-nix"
```

---

### Task 3: Swap `hermes-gateway` for `hermes-agent` in `strix-halo.nix`

**Files:**
- Modify: `hosts/strix-halo.nix`

- [ ] **Step 1: Remove `hermes-gateway` from imports**

Remove this line from the `imports` list in `hosts/strix-halo.nix`:

```nix
    inputs.nixos-server.nixosModules.hermes-gateway
```

- [ ] **Step 2: Add `hermes-agent` module to imports**

Add this line to the `imports` list (after the other `nixos-server` module imports):

```nix
    inputs.hermes-agent.nixosModules.default
```

- [ ] **Step 3: Replace the `services.hermes-gateway` block with `services.hermes-agent` and add sops config**

Replace the entire block:

```nix
  services.hermes-gateway = {
    enable = true;
    hermesHome = "/home/yztangent/.hermes/";
  };
```

with:

```nix
  sops = {
    defaultSopsFile = ../secrets/strix-halo-hermes.yaml;
    age.keyFile = "/home/yztangent/.config/sops/age/keys.txt";
    secrets."hermes-env" = { format = "yaml"; };
  };

  services.hermes-agent = {
    enable = true;
    container.enable = true;
    container.backend = "docker";
    container.hostUsers = [ "yztangent" ];
    extraDependencyGroups = [ "messaging" ];
    environmentFiles = [ config.sops.secrets."hermes-env".path ];
    settings = {};
    mcpServers = {};
    documents = {};
  };
```

Notes:
- `sops.secrets."hermes-env".path` is the sops-nix-managed decrypted path; systemd reads it at service start — never pass the raw encrypted file to `environmentFiles`
- `container.hostUsers = [ "yztangent" ]` creates `~/.hermes` symlink to `/var/lib/hermes/.hermes` and auto-adds `yztangent` to the `hermes` group
- `extraDependencyGroups = [ "messaging" ]` includes the messaging pyproject.toml extra (Discord, Telegram, Slack) in the sealed venv
- `settings`, `mcpServers`, and `documents` are empty for now; populate them later as needed

- [ ] **Step 4: Commit**

```bash
git add hosts/strix-halo.nix
git commit -m "strix-halo: replace hermes-gateway with official hermes-agent module"
```

---

### Task 4: Update flake.lock

**Files:**
- Modify: `flake.lock` (auto-generated)

- [ ] **Step 1: Run `nix flake update hermes-agent`** to fetch the new input and update `flake.lock`

Run: `nix flake update hermes-agent`
Expected: `flake.lock` is updated with the new `hermes-agent` revision.

- [ ] **Step 2: Commit the updated lock file**

```bash
git add flake.lock
git commit -m "lock: update flake.lock with hermes-agent input"
```

---

### Task 5: Post-rebuild verification steps (manual, not committed)

These are **not committed** — they are manual instructions to run after the NixOS rebuild:

- [ ] **Step 1: Build and switch**

```bash
sudo nixos-rebuild switch
```

- [ ] **Step 2: Migrate old state**

```bash
mv /home/yztangent/.hermes/ /home/yztangent/.hermes.bak/
```

- [ ] **Step 3: Remove stale `/var/lib/hermes/`** (the old bind-mount service may have left state there that conflicts with the container's state management)

```bash
sudo rm -rf /var/lib/hermes/
```

- [ ] **Step 4: Verify the container is running and secrets loaded**

```bash
systemctl status hermes-agent
docker exec hermes-agent cat /data/.hermes/.env
```

The `.env` file should contain `TELEGRAM_BOT_TOKEN=...` (sops-nix decrypted it at activation time into the container).

- [ ] **Step 5: Inspect the container**

```bash
docker exec -it hermes-agent bash
```

---

## Self-Review

**1. Spec coverage:**
- Flake input addition → Task 1 ✓
- Outputs destructuring update → Task 1 ✓
- Remove `hermes-gateway` import → Task 3, Step 1 ✓
- Add `hermes-agent` import → Task 3, Step 2 ✓
- Replace `services.hermes-gateway` with `services.hermes-agent` config → Task 3, Step 3 ✓
- `sops.secrets."hermes-env"` declaration + `environmentFiles = [ config.sops.secrets."hermes-env".path ]` → Task 3, Step 3 ✓
- sops YAML secrets file (`secrets/strix-halo-hermes.yaml`) with Telegram token → Task 2 ✓
- `.sops.yaml` creation/recreation → Task 2, Step 1 ✓
- Post-rebuild manual steps (rename `.hermes`, nuke `/var/lib/hermes/`, verify secrets, inspect container) → Task 5 ✓
- Official docs link in both req and plan ✓
- No CLI config commands (`hermes configure` / `hermes setup` removed) ✓

**2. Placeholder scan:** No placeholders found. Every step has exact code or commands.

**3. Type consistency:** All attribute paths match the official docs exactly (`container.enable`, `container.backend`, `container.hostUsers`, `extraDependencyGroups`, `environmentFiles`, `settings`, `mcpServers`, `documents`). `environmentFiles` correctly references `config.sops.secrets."hermes-env".path` — not the raw encrypted file.

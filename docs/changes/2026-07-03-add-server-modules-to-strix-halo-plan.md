# Add Server Modules to strix-halo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure strix-halo as the bootstrap node of a multi-node k3s cluster with llama.cpp inference and Cloudflare tunnels, by importing four service modules from `github:yztangent/nixos-server` and setting up sops-nix for secrets management.

**Architecture:** Add two flake inputs (`nixos-server`, `sops-nix`), import four service modules into `hosts/strix-halo.nix`, and register sops-nix with age-based encryption. The server flake provides ready-made NixOS modules — this change wires them into the strix-halo host configuration.

**Tech Stack:** Nix, Flakes, NixOS, k3s, llama.cpp, Cloudflare Tunnels, SOPS

---

### Task 1: Add flake inputs for `nixos-server` and `sops-nix`

**Files:**
- Modify: `/home/yztangent/.home/flake.nix`

- [ ] **Step 1: Add `nixos-server` and `sops-nix` inputs**

Insert into the `inputs` block in `flake.nix`:

```nix
    nixos-server = {
      url = "github:yztangent/nixos-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

- [ ] **Step 2: Update `outputs` closure to include new inputs**

Change the outputs line from:
```nix
  outputs = { self, nixpkgs, home-manager, darwin, ... }@inputs: {
```
To:
```nix
  outputs = { self, nixpkgs, home-manager, darwin, nixos-server, sops-nix, ... }@inputs: {
```

- [ ] **Step 3: Update `flake.lock` and verify evaluation**

```bash
cd /home/yztangent/.home
nix flake lock --update-input nixos-server --update-input sops-nix
nix flake show
```
Expected: Output shows both `nixos-server` and `sops-nix` as inputs, and all configurations (`strix-halo`, `legion`, `l13`, `x395`, `macbook`) still listed.

- [ ] **Step 4: Commit**

```bash
cd /home/yztangent/.home
git add flake.nix flake.lock
git commit -m "feat: add nixos-server and sops-nix flake inputs"
```

---

### Task 2: Provision age keypair and create encrypted secrets

**Files:**
- Create: `/home/yztangent/.home/secrets/strix-halo.yaml` (encrypted secrets file)
- Create: `/home/yztangent/.home/.ssh/sops-strix-halo` (age private key — **DO NOT commit**)
- Modify: `/home/yztangent/.home/.gitignore` (exclude age private key)

- [ ] **Step 1: Generate age keypair for strix-halo**

```bash
cd /home/yztangent/.home
mkdir -p secrets .ssh
age-keygen -o .ssh/sops-strix-halo 2>&1 | grep "Public key:" | awk '{print $3}' > secrets/strix-halo.age.pub
```

Record the public key from the output — it will be needed for the secrets file.

- [ ] **Step 2: Create encrypted secrets file**

```bash
cd /home/yztangent/.home

# Generate plaintext values
k3s_token=$(openssl rand -hex 32)
k3s_vrrp=$(openssl rand -base64 32)
cat > /tmp/strix-halo-secrets-plain.yaml <<EOF
k3s-token: ${k3s_token}
k3s-vrrp-password: ${k3s_vrrp}
cloudflared-credentials: '{}'
EOF

# Encrypt with sops
sops --age "$(cat secrets/strix-halo.age.pub)" \
  --encrypt \
  --in-place \
  /tmp/strix-halo-secrets-plain.yaml

# Move to final location
mv /tmp/strix-halo-secrets-plain.yaml secrets/strix-halo.yaml
```

- [ ] **Step 3: Add age private key to `.gitignore`**

```bash
cd /home/yztangent/.home
echo ".ssh/sops-strix-halo" >> .gitignore
```

- [ ] **Step 4: Commit**

```bash
cd /home/yztangent/.home
git add secrets/strix-halo.yaml secrets/strix-halo.age.pub .gitignore
git commit -m "chore: add age keypair and encrypted SOPS secrets for strix-halo"
```

---

### Task 3: Import and enable server service modules on strix-halo

**Files:**
- Modify: `/home/yztangent/.home/hosts/strix-halo.nix`

- [ ] **Step 1: Rewrite `strix-halo.nix` to import modules and enable services**

Replace the entire contents of `hosts/strix-halo.nix` with:

```nix
{ config, pkgs, inputs, ... }:

{
  networking.hostName = "strix-halo";
  networking.hostId = "strxhalo";

  imports = [
    ./default.nix
    ../hardware/strix-hardware-configuration.nix
    ../hardware/gpu/amd.nix
    inputs.sops-nix.nixosModules.sops
    inputs.nixos-server.nixosModules.k3s
    inputs.nixos-server.nixosModules.llama-server
    inputs.nixos-server.nixosModules.monitoring-agent
    inputs.nixos-server.nixosModules.cloudflare-tunnels
  ];

  services.k3s-server = {
    enable = true;
    isFirstNode = true;   # bootstrap this machine as cluster leader
    flannelIface = "wlp195s0";
  };

  services.llama-server = {
    enable = true;
    instances.chat = {
      port = 11434;
      extraArgs = [ "-ngl" "99" "--backend" "vulkan" ];
    };
  };

  services.monitoring-agent.enable = true;

  services.nixos-server.cloudflare-tunnels = {
    enable = true;
    hostTunnel = {
      enable = true;
      credentialsFile = config.sops.secrets."cloudflared-credentials".path;
    };
    computeTunnel = {
      enable = true;
      credentialsFile = config.sops.secrets."cloudflared-credentials".path;
      ingress = {};
    };
  };

  sops = {
    defaultSopsFile = ../secrets/strix-halo.yaml;
    age.keyFile = /home/yztangent/.ssh/sops-strix-halo;
    secrets = {
      "k3s-token" = {};
      "k3s-vrrp-password" = {};
      "cloudflared-credentials" = {};
    };
  };
}
```

Key details:
- `flannelIface = "wlp195s0"` — WiFi interface for flannel VXLAN traffic
- `isFirstNode = true` — k3s module sets `clusterInit = true` and keepalived priority 150
- `--backend vulkan` — llama.cpp uses Vulkan backend via the `llama-cpp-vulkan` overlay
- `ingress = {}` — no public endpoints yet; tunnel credentials still needed for hostTunnel WARP
- Both `hostTunnel` and `computeTunnel` enabled; both reference the same SOPS secret
- `defaultSopsFile` uses `../secrets/` relative path from `hosts/strix-halo.nix` → flake root `secrets/`

- [ ] **Step 2: Verify evaluation**

```bash
cd /home/yztangent/.home
nix build .#strix-halo.config.system.build.toplevel
```
Expected: Clean evaluation with no errors.

- [ ] **Step 3: Final verification — diff**

```bash
cd /home/yztangent/.home
git diff --stat
```
Expected: Changes only in `flake.nix`, `flake.lock`, `hosts/strix-halo.nix`, `secrets/strix-halo.yaml`, `.gitignore`.

- [ ] **Step 4: Commit**

```bash
cd /home/yztangent/.home
git add hosts/strix-halo.nix
git commit -m "feat: import k3s, llama-server, monitoring-agent, cloudflare-tunnels modules"
```

---

## File Summary

| File | Action | Purpose |
|------|--------|---------|
| `flake.nix` | Modify | Add `nixos-server` and `sops-nix` inputs |
| `flake.lock` | Update | Lock new flake inputs |
| `hosts/strix-halo.nix` | Modify | Import modules, enable k3s/llama/monitoring/cloudflare-tunnels, add sops config |
| `secrets/strix-halo.yaml` | Create | Encrypted SOPS secrets file |
| `.ssh/sops-strix-halo` | Create | Age private key (gitignored) |
| `.gitignore` | Modify | Exclude age private key |

## Non-goals (unchanged from requirement)

- No disko or device-id integration
- No actual Cloudflare tunnel credentials (obtained from dashboard later)
- No k3s join token persistence (generated fresh each time, stored in SOPS)

## Verification Checklist

- [ ] `nix build .#strix-halo.config.system.build.toplevel` evaluates without errors
- [ ] `nix flake show` lists all 5 NixOS configs + 1 Darwin config
- [ ] `git diff --stat` shows only the 6 expected files changed
- [ ] Age private key is gitignored

# Requirement: Add server modules to strix-halo

## Summary

Configure strix-halo (this machine) as the first node of a multi-node k3s cluster with llama.cpp inference serving, by importing service modules from `github:yztangent/nixos-server` via flake input. This is the bootstrap node — it bootstraps itself and will eventually accept joins from other nodes.

## Context

- strix-halo has an AMD iGPU (Vulkan via RADV) suitable for llama.cpp inference
- WiFi interface `wlp195s0` connects to the gateway/router
- The server flake at `github:yztangent/nixos-server` exports `k3s`, `llama-server`, `monitoring-agent`, and `cloudflare-tunnels` modules.
- This machine has no existing SOPS or k8s configuration

## Changes

### 1. Flake input: nixos-server

Add to `flake.nix` inputs:

```nix
nixos-server = {
  url = "github:yztangent/nixos-server";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

This imports the server flake's public module interface. Modules are consumed via `inputs.nixos-server.nixosModules.<module>`.

### 2. Flake input: sops-nix

Add as a new flake input (this machine needs its own copy since the server's sops-nix is scoped to its own nixpkgs):

```nix
sops-nix = {
  url = "github:Mic92/sops-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

### 3. strix-halo.nix: import and enable services

Add to `imports` in `hosts/strix-halo.nix`:

- `inputs.sops-nix.nixosModules.sops` (register sops-nix with NixOS)
- `inputs.nixos-server.nixosModules.k3s`
- `inputs.nixos-server.nixosModules.llama-server`
- `inputs.nixos-server.nixosModules.monitoring-agent`
- `inputs.nixos-server.nixosModules.cloudflare-tunnels`

Enable the services:

```nix
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
```

The k3s module defaults (`clusterInit = true`, `role = "server"` from the server flake's compute.nix profile) apply automatically — strix-halo bootstraps itself as the first node.

### 4. SOPS-nix configuration

Register sops-nix in the host config (in default.nix or a dedicated module). Generate an age keypair for this machine and create an initial secrets file at `secrets/strix-halo.yaml` with entries for:
- `k3s-token` — k3s cluster join token (generated on first boot, stored encrypted)
- `vrrp-password` — keepalived VRRP authentication password
- `cloudflared-credentials` — JSON credentials for the Cloudflare tunnel

The age identity must be provisioned before the first `nixos-rebuild switch`.

## Non-goals

- No disko or device-id integration (these are server-cluster provisioning concerns)

## Verification

After implementation:
1. `nix build .#strix-halo.config.system.build.toplevel` evaluates without errors
2. `k3s kubectl get nodes` shows at least one node after first boot
3. `curl http://localhost:11434/api/tags` returns llama-server model list

## Scope

Single focused change: add two service modules plus sops-nix scaffolding to make strix-halo the bootstrap node of a k3s cluster with AI inference capability. No architectural decisions beyond what's already encoded in the server flake's module design.

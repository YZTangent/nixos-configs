# macOS Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the existing NixOS configuration flake to support macOS (nix-darwin) alongside NixOS, sharing common packages and dotfiles via Home Manager.

**Architecture:** We will split `packages.nix` into `common-packages.nix` and `linux-packages.nix`, update the NixOS host base, create a macOS host base, and update `flake.nix` to expose both `nixosConfigurations` and `darwinConfigurations`.

**Tech Stack:** Nix, Flakes, nix-darwin, home-manager

---

### Task 1: Split `packages.nix` into `common-packages.nix`

**Files:**
- Create: `/home/yztangent/.home/modules/common-packages.nix`

- [ ] **Step 1: Create `common-packages.nix`**

```nix
{ pkgs, ... }:

let
  # CLI utilities (wl-clipboard removed as it's Wayland/Linux specific)
  utils = with pkgs; [ fzf ripgrep fd zip unzip git jq ];
  
  # Editors
  editors = with pkgs; [ vim neovim tree-sitter ];
  
  # Dev tools
  devtools = with pkgs; [ nodejs python3 uv ];
  
  # Devops
  devops = [ pkgs.docker-compose ];
in
{
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages =
    editors ++
    utils ++
    devtools ++
    devops;

  programs.fish.enable = true;
}
```
`

### Task 2: Refactor `packages.nix` to `linux-packages.nix`

**Files:**
- Create: `/home/yztangent/.home/modules/linux-packages.nix`
- Modify (Delete): `/home/yztangent/.home/modules/packages.nix`

- [ ] **Step 1: Create `linux-packages.nix` containing only Linux-specific configs**

```nix
{ pkgs, ... }:

let
  wayland = [ pkgs.xwayland-satellite pkgs.wl-clipboard ];
in
{
  security.sudo.enable = true;

  environment.systemPackages = wayland;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [ stdenv.cc.cc ];

  programs.niri.enable = true;
  programs.xwayland.enable = true;
  programs.steam.enable = true;
  programs.firefox.enable = true;
}
```

- [ ] **Step 2: Delete `packages.nix`**

```bash
cd /home/yztangent/.home
rm modules/packages.nix
```

- [ ] **Step 3: Commit**

```bash
cd /home/yztangent/.home
git add modules/linux-packages.nix modules/packages.nix modules/common-packages.nix
git commit -m "refactor: split packages into linux specifi and common packages"
```

### Task 3: Update NixOS `default.nix` host base

**Files:**
- Modify: `/home/yztangent/.home/hosts/default.nix`

- [ ] **Step 1: Replace `packages.nix` with `common-packages.nix` and `linux-packages.nix`**

Use `sed` or an editor to change line 13 in `/home/yztangent/.home/hosts/default.nix`:
From:
```nix
    ../modules/packages.nix
```
To:
```nix
    ../modules/common-packages.nix
    ../modules/linux-packages.nix
```

- [ ] **Step 2: Check evaluation**

```bash
cd /home/yztangent/.home
nix flake show
```
Expected: successful evaluation, showing `nixosConfigurations` output.

- [ ] **Step 3: Commit**

```bash
cd /home/yztangent/.home
git add hosts/default.nix
git commit -m "refactor: update NixOS host base to use split package modules"
```

### Task 4: Create macOS `macbook.nix` host base

**Files:**
- Create: `/home/yztangent/.home/hosts/macbook.nix`

- [ ] **Step 1: Write `macbook.nix`**

```nix
{ config, pkgs, inputs, ... }:

let
  stateVersion = 4;
in
{
  imports = [
    ../modules/common-packages.nix
    inputs.home-manager.darwinModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.yztangent = import ../home;
      home-manager.backupFileExtension = "backup";
      home-manager.extraSpecialArgs = { inherit inputs; hostName = "macbook"; };
    }
  ];

  services.nix-daemon.enable = true;
  system.stateVersion = stateVersion;
}
```

- [ ] **Step 2: Commit**

```bash
cd /home/yztangent/.home
git add hosts/macbook.nix
git commit -m "feat: add macOS host configuration base"
```

### Task 5: Update `flake.nix` to add nix-darwin

**Files:**
- Modify: `/home/yztangent/.home/flake.nix`

- [ ] **Step 1: Add darwin input to `flake.nix`**

Insert darwin into the `inputs` block:
```nix
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

- [ ] **Step 2: Add `darwinConfigurations` output to `flake.nix`**

Add `darwin` to the outputs closure: `outputs = { self, nixpkgs, home-manager, darwin, ... }@inputs:`
Add the darwin configuration below `nixosConfigurations`:
```nix
    darwinConfigurations = {
      macbook = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/macbook.nix ];
      };
    };
```

- [ ] **Step 3: Update `flake.lock` and check evaluation**

```bash
cd /home/yztangent/.home
nix flake lock --update-input darwin
nix flake show
```
Expected: Output showing both `nixosConfigurations` and `darwinConfigurations`.

- [ ] **Step 4: Commit**

```bash
cd /home/yztangent/.home
git add flake.nix flake.lock
git commit -m "feat: add nix-darwin support and macbook configuration"
```

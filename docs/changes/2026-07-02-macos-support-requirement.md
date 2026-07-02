# Requirement: Abstract NixOS Configuration for macOS Support

## 1. Context and Objective
The current configuration inside `~/.home/` is tightly coupled to NixOS (Linux). The goal is to refactor this structure so it can manage both the existing NixOS machines (Legion, L13, X395) and a new Apple Silicon MacBook via `nix-darwin`, while sharing as much configuration as possible (specifically dotfiles and common CLI packages) via Home Manager.

## 2. Current State
- Flake entrypoint (`flake.nix`) is solely defining `nixosConfigurations`.
- Modules (`modules/packages.nix`, `modules/docker.nix`, `modules/services.nix`, etc.) contain a mix of common packages (vim, fzf) and Linux-specific packages (xwayland-satellite, niri) and services (systemd, docker).
- Home Manager setup (`home/default.nix`, `home/modules/`) works cross-platform but had hardcoded Linux paths which have already been fixed.

## 3. Proposed Architecture

### Flake Structure
- Add `nix-darwin` to the flake inputs.
- Output `darwinConfigurations` alongside `nixosConfigurations`.
- Create a new host file for the MacBook (e.g., `hosts/macbook.nix`).

### Module Separation
We will split the system-level modules to isolate Linux/NixOS concepts from macOS/Darwin concepts:

1.  **`modules/common-packages.nix`**: 
    - CLI tools that run on both Linux and macOS (vim, neovim, nodejs, python3, fzf, ripgrep, etc.).
    - Nix settings (flakes enabled, unfree allowed).
2.  **`modules/linux-packages.nix`**: 
    - Wayland, Niri, Steam, Linux-specific desktop environments.
3.  **`hosts/default.nix` (NixOS base)**: 
    - Imports `bootloader.nix`, `network.nix`, `daemons.nix`, `docker.nix`, and `linux-packages.nix`.
4.  **`hosts/macbook.nix` (Darwin base)**: 
    - Imports `common-packages.nix` and darwin-specific settings (e.g., `services.nix-daemon.enable = true`).
    - Excludes Linux-specific modules.

### Home Manager (User Configuration)
- The existing `home/default.nix` will be imported by both NixOS and Darwin configurations.
- Dotfiles management (symlinking `~/.home/dotfiles/` to `~/.config/`) will remain unified.

## 4. Scope of Work
- [ ] Refactor `modules/packages.nix` into `common-packages.nix` and `linux-packages.nix`.
- [ ] Update `hosts/default.nix` to use the refactored package modules.
- [ ] Create `hosts/macbook.nix` with a baseline `nix-darwin` configuration.
- [ ] Update `flake.nix` inputs and outputs to support the new `macbook` host.

## 5. Non-Goals
- We are not porting Linux GUI applications (like Niri or Waybar) to macOS.
- We are not changing the structure of the dotfiles themselves, only how the Nix flake consumes them.

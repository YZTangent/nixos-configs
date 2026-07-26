# Replace Custom Hermes Gateway with Official Module

## Overview

Replace the custom `hermes-gateway` NixOS module from `nixos-server` with the official `hermes-agent` module from `github:NousResearch/hermes-agent`. The new module manages the full Hermes Agent lifecycle (user creation, config generation, secrets, service lifecycle) and runs in Docker container mode.

**Official docs:** <https://hermes-agent.nousresearch.com/docs/getting-started/nix-setup>

In NixOS managed mode, **all CLI config commands are blocked** (`HERMES_MANAGED` guard). Configuration is declarative via `settings` (renders `config.yaml`), secrets go through `environmentFiles` (merged into `$HERMES_HOME/.env`), and service lifecycle is a systemd unit.

## Changes

### Flake inputs (`flake.nix`)

- **Add** `hermes-agent` input:
  ```nix
  hermes-agent = {
    url = "github:NousResearch/hermes-agent";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  ```
- Add `hermes-agent` to the outputs destructuring.

### Strix-halo host config (`hosts/strix-halo.nix`)

- **Remove** `inputs.nixos-server.nixosModules.hermes-gateway` from imports.
- **Remove** the entire `services.hermes-gateway` block.
- **Add** `inputs.hermes-agent.nixosModules.default` to imports.
- **Add** `services.hermes-agent` configuration:
  ```nix
  services.hermes-agent = {
    enable = true;
    container.enable = true;
    container.backend = "docker";
    container.hostUsers = [ "yztangent" ];
    extraDependencyGroups = [ "messaging" ];
    environmentFiles = [ ../secrets/strix-halo-hermes.env.enc ];
    settings = {};
    mcpServers = {};
    documents = {};
  };
  ```

## State Migration

No config migration — fresh start.

- `/home/yztangent/.hermes/` → renamed to `/home/yztangent/.hermes.bak/` (manual step, preserves old config for reference).
- `/var/lib/hermes/` → removed entirely (nuked) to avoid stale state from the old bind-mount service conflicting with the official module's container state management.

## Runtime Behavior

- **Container mode**: Hermes runs in a persistent Ubuntu 24.04 Docker container with `/nix/store` bind-mounted read-only.
- **State directory**: `/var/lib/hermes/` managed by the official module.
- **Host access**: `yztangent` gets a `~/.hermes` symlink pointing to `/var/lib/hermes/.hermes` and is added to the `hermes` group.
- **Messaging**: Telegram support via `extraDependencyGroups = [ "messaging" ]` to include the messaging pyproject.toml extra (Discord, Telegram, Slack) in the sealed venv. We use the default (full) package but still need this to enable the extras.

## Post-Rebuild Steps

1. `sudo nixos-rebuild switch`
2. Migrate Telegram bot token from old `/home/yztangent/.hermes/config.yaml` into a new sops-nix-encrypted env file and add it to `environmentFiles`.
3. Migrate any custom `config.yaml` settings (model, skills, etc.) into the `services.hermes-agent.settings` attrset.
4. `docker exec -it hermes-agent bash` for container inspection.

## Files Modified

- `flake.nix` — add input, update outputs
- `hosts/strix-halo.nix` — swap module, new config

## Manual Steps Required

1. After rebuild, rename `/home/yztangent/.hermes/` → `/home/yztangent/.hermes.bak/`
2. The rebuild itself removes `/var/lib/hermes/` (stale state)

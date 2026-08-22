{ config, inputs, ... }:

{
  networking.hostName = "strix-halo";
  networking.hostId = builtins.substring 0 8 (builtins.hashString "sha256" "strix-halo");

  imports = [
    ./default.nix
    ../hardware/strix-hardware-configuration.nix
    ../hardware/gpu/amd.nix
    inputs.sops-nix.nixosModules.sops
    inputs.nixos-server.nixosModules.k3s
    inputs.nixos-server.nixosModules.llama-server
    inputs.nixos-server.nixosModules.monitoring-agent
    inputs.nixos-server.nixosModules.cloudflare-tunnels
    inputs.hermes-agent.nixosModules.default
  ];

  services.k3s-server = {
    enable = true;
    isFirstNode = true;
    flannelIface = "wlp195s0";
  };

  services.llama-server = {
    enable = true;
    instances.chat = {
      port = 11434;
      modelsPreset = "/etc/llama-server/models.ini";
      bindReadOnlyPaths = [
        "/home/yztangent/.home/dotfiles/llama-server:/etc/llama-server"
        "/data/models/lmstudio:/var/lib/llama-lmstudio"
      ];
      extraArgs = [ "-ngl" "999" "--no-mmap" ];
    };
  };

  # Secondary nvme mounted at /data. The root of a fresh ext4 fs is root-owned,
  # so tmpfiles fixes ownership here (ext4 ignores uid=/gid= mount options).
  # /data stays 0755 so service users like llama can traverse it read-only.
  systemd.tmpfiles.rules = [
    "d /data 0755 ${config.users.users.yztangent.name} users - -"
    "d /data/models 0755 ${config.users.users.yztangent.name} users - -"
    "d /data/models/lmstudio 0755 ${config.users.users.yztangent.name} users - -"
    # comfyui model cache lives on /data now; legacy path kept as a symlink
    "d /data/models/comfyui 2775 ${config.users.users.yztangent.name} users - -"
    "L /var/lib/comfyui-models - - - - /data/models/comfyui"
  ];

  services.monitoring-agent.enable = true;

  services.nixos-server.cloudflare-tunnels = {
    enable = false;
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

  services.hermes-agent = {
    enable = true;
    container.enable = true;
    container.backend = "docker";
    container.hostUsers = [ "yztangent" ];
    extraDependencyGroups = [ "messaging" ];
    environmentFiles = [ config.sops.secrets."hermes-env".path ];
    settings = {
      model = {
        default = "Qwen3.6-35B";
        provider = "custom";
        base_url = "http://localhost:11434/v1";
      };
    };
    mcpServers = {};
    documents = {};
  };

  sops = {
    defaultSopsFile = ../secrets/strix-halo.yaml;
    age.keyFile = "/home/yztangent/.ssh/sops-strix-halo";
    secrets = {
      "k3s-token" = {};
      "k3s-vrrp-password" = {};
      "cloudflared-credentials" = {};
      "hermes-env" = {
        format = "yaml";
        sopsFile = ../secrets/strix-halo-hermes.yaml;
      };
    };
  };
}

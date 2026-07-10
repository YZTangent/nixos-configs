{ config, pkgs, inputs, ... }:

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
      modelsDir = "/var/lib/llama-models";
      extraArgs = [ "-ngl" "99" ];
    };
  };

  systemd.tmpfiles.rules = [
    # Model directory for llama-cpp and LM-Studio
    "d /var/lib/llama-models 2775 llama users - -"
    # Model directory for comfyui
    "d /var/lib/comfyui-models 2775 ${config.users.users.yztangent.name} users - -"
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

  sops = {
    defaultSopsFile = ../secrets/strix-halo.yaml;
    age.keyFile = "/home/yztangent/.ssh/sops-strix-halo";
    secrets = {
      "k3s-token" = {};
      "k3s-vrrp-password" = {};
      "cloudflared-credentials" = {};
    };
  };
}

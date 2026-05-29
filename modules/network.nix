{ ... }:

{
  # networking.hostName is set per-host in hosts/<hostname>.nix
  networking.networkmanager.enable = true;

  networking.firewall.allowedTCPPorts = [ 1883 ];
}

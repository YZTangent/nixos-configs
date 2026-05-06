{ ... }:

{
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  networking.firewall.allowedTCPPorts = [ 1883 ];
}

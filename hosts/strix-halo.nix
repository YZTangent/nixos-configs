{ ... }:

{
  networking.hostName = "strix-halo";

  imports = [
    ./default.nix
    ../hardware/strix-hardware-configuration.nix
  ];
}

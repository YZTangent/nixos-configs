{ ... }:

{
  networking.hostName = "strix-halo";
  networking.hostId = "strxhalo";

  imports = [
    ./default.nix
    ../hardware/strix-hardware-configuration.nix
    ../hardware/gpu/amd.nix
  ];
}

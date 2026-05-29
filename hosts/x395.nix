{ ... }:

{
  networking.hostName = "x395";

  imports = [
    ./default.nix
    ../hardware/x395-hardware-configuration.nix
    ../hardware/gpu/amd.nix
  ];
}

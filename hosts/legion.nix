{ ... }:

{
  imports = [
    ./default.nix
    ../hardware/legion-hardware-configuration.nix
    ../hardware/gpu/nvidia.nix
  ];
}

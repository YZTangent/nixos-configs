{ ... }:

{
  imports = [
    ./default.nix
    ../hardware/l13-hardware-configuration.nix
    ../hardware/gpu/intel.nix
  ];
}

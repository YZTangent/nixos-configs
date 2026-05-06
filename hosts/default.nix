{ config, pkgs, inputs, ... }:

let
  stateVersion = "25.11";
in
{
  imports = [
    ../modules/bootloader.nix
    ../modules/network.nix
    ../modules/services.nix
    ../modules/daemons.nix
    ../modules/docker.nix
    ../modules/packages.nix
    ../modules/user.nix
    inputs.minegrub-theme.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.yztangent = import ../home;
      home-manager.backupFileExtension = "backup";
      home-manager.extraSpecialArgs = { inherit inputs; };
    }
  ];

  system.stateVersion = stateVersion;
  home-manager.users.yztangent.home.stateVersion = stateVersion;
}

{ config, pkgs, inputs, ... }:

let
  stateVersion = 4;
in
{
  imports = [
    ../modules/common-packages.nix
    inputs.home-manager.darwinModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.yztangent = import ../home;
      home-manager.backupFileExtension = "backup";
      home-manager.extraSpecialArgs = { inherit inputs; hostName = "macbook"; };
    }
  ];

  services.nix-daemon.enable = true;
  system.stateVersion = stateVersion;
}

{ ... }:

{
  home.username = "yztangent";
  home.homeDirectory = "/home/yztangent";

  imports = [
    ./modules/dotfiles.nix
    ./modules/fonts.nix
    ./modules/packages.nix
  ];

  programs.home-manager.enable = true;
}

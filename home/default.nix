{ ... }:

{
  home.username = "yztangent";
  home.homeDirectory = "/home/yztangent";

  imports = [
    ./modules/dotfiles.nix
    ./modules/programs.nix
    ./modules/fonts.nix
    ./modules/user-packages.nix
  ];

  programs.home-manager.enable = true;
}

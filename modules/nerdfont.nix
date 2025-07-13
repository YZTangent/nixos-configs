# /etc/nixos/modules/nerdfonts.nix
{ pkgs, ... }:

{
  # Install fonts for the user
  home.packages = [
    pkgs.nerd-fonts.jetbrains-mono
  ];
}

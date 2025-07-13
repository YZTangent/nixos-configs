# /etc/nixos/modules/fish.nix
{ pkgs, ... }:

{
  programs.fish = {
    enable = true;
    shellAbbrs = {
      ls = "eza";
      ll = "eza -l";
      la = "eza -a";
    };
  };
}

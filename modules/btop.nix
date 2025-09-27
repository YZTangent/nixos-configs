# /etc/nixos/modules/btop.nix
{ pkgs, ... }:

{
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "tokyo-storm";
      theme_background = false;
    };
  };
}

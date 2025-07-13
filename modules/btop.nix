# /etc/nixos/modules/btop.nix
{ pkgs, ... }:

{
  home.packages = [ pkgs.btop ];
}

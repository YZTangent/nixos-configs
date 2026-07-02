{ pkgs, ... }:

let
  wayland = [ pkgs.xwayland-satellite pkgs.wl-clipboard ];
in
{
  security.sudo.enable = true;

  environment.systemPackages = wayland;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [ stdenv.cc.cc ];

  programs.niri.enable = true;
  programs.xwayland.enable = true;
  programs.steam.enable = true;
  programs.firefox.enable = true;
}

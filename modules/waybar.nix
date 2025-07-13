# /etc/nixos/modules/waybar.nix
{ pkgs, ... }:

{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        modules-left = [ "niri/workspaces" "niri/mode" ];
        modules-center = [ "clock" ];
        modules-right = [ "pulseaudio" "network" "battery" "tray" ];
        "niri/workspaces" = {
          "all-outputs" = true;
          "on-click" = "activate";
        };
        "clock" = {
          "format" = "{:%H:%M}";
          "tooltip-format" = "<big>{:%Y-%m-%d}</big>\n<tt><small>{calendar}</small></tt>";
        };
      };
    };
  };
}

# /etc/nixos/modules/waybar.nix
{ pkgs, ... }:

{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "left";
	orientation = "vertical";
        modules-left = [ "niri/workspaces" "niri/mode" ];
        modules-center = [ "clock" ];
        modules-right = [ "pulseaudio" "network" "battery" "cpu" "memory" "tray" ];
        "niri/workspaces" = {
          "all-outputs" = true;
          "on-click" = "activate";
        };
        "clock" = {
          "format" = "{:%H\n%M}";
          "tooltip-format" = "<big>{:%A %d %h %Y}</big>\n<tt><small>{calendar}</small></tt>";
        };
        "cpu" = {
          "format" = "<span foreground='#8ec07c'></span> {usage}%";
        };
        "memory" = {
          "format" = "<span foreground='#d79921'>Mem</span> {used:0.1f}G";
        };
      };
    };
  };
}

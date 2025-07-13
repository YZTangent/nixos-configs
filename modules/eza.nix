# /etc/nixos/modules/eza.nix
{ ... }:

{
  programs.eza = {
    enable = true;
    enableFishIntegration = true;
    git = true;
    icons = "auto";
  };
}

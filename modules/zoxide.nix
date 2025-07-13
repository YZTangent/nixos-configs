# /etc/nixos/modules/zoxide.nix
{ ... }:

{
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
}

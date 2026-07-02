{ pkgs, ... }:

let
  # CLI utilities (wl-clipboard removed as it's Wayland/Linux specific)
  utils = with pkgs; [ fzf ripgrep fd zip unzip git jq ];
  
  # Editors
  editors = with pkgs; [ vim neovim tree-sitter ];
  
  # Dev tools
  devtools = with pkgs; [ nodejs python3 uv ];
  
  # Devops
  devops = [ pkgs.docker-compose ];
in
{
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages =
    editors ++
    utils ++
    devtools ++
    devops;

  programs.fish.enable = true;
}

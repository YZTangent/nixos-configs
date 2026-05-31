{ pkgs, ... }:

let
  # CLI utilities
  utils = with pkgs; [ fzf ripgrep fd zip unzip wl-clipboard git jq ];

  # Editors
  editors = with pkgs; [ vim neovim tree-sitter ];

  # Dev tools
  devtools = with pkgs; [ nodejs python3 uv ];

  # Devops
  devops = [ pkgs.docker-compose ];

  # Wayland infrastructure
  wayland = [ pkgs.xwayland-satellite ];
in
{
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  security.sudo.enable = true;

  environment.systemPackages =
    editors ++
    utils ++
    devtools ++
    devops ++
    wayland;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [ stdenv.cc.cc ];

  programs.niri.enable = true;
  programs.xwayland.enable = true;
  programs.steam.enable = true;
  programs.fish.enable = true;
  programs.firefox.enable = true;
}

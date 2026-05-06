{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  security.sudo.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    neovim
    git
    gnumake
    clang
    clang-tools
    cmake
    fzf
    ripgrep
    fd
    wl-clipboard
    godot
    rustup
    go
    unzip
    pkg-config
    xwayland-satellite
    gemini-cli
    claude-code
    onedriver
    docker-compose
  ];

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [ stdenv.cc.cc ];
}

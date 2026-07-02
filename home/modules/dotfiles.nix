{ config, lib, hostName, ... }:

let
  dotfilesDir = "${config.home.homeDirectory}/.home/dotfiles";
in
{
  home.file.".config/niri" =
    if hostName == "l13" then {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/niri-l13";
      recursive = true;
    } else {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/niri";
      recursive = true;
    };

  home.file.".config/waybar" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/waybar";
    recursive = true;
  };

  home.file.".config/swaylock" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/swaylock";
    recursive = true;
  };

  home.file.".config/nvim" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/nvim";
    recursive = true;
  };

  home.file.".gitconfig" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/git/.gitconfig";
  };

  home.file.".config/alacritty" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/alacritty";
    recursive = true;
  };

  home.file.".config/ghostty" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/ghostty";
    recursive = true;
  };

  home.file.".config/btop" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/btop";
    recursive = true;
  };

  home.file.".config/starship.toml" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/starship/starship.toml";
  };

  home.file.".config/fish/config.fish" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/fish/config.fish";
  };

  home.file.".config/opencode" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/opencode";
    recursive = true;
  };

  home.file.".agents" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/agents";
    recursive = true;
  };

  home.file.".claude" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude";
    recursive = true;
  };

  home.file.".gemini" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/gemini";
    recursive = true;
  };
}

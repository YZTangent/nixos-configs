{ config, lib, hostName, ... }:

let
  dotfilesDir = "/home/yztangent/.home/dotfiles";
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

  home.file.".claude/skills" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/skills";
    recursive = true;
  };

  home.file.".agents/skills" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/skills";
    recursive = true;
  };
}

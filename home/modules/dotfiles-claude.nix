# REFERENCE MODULE — not imported, kept for learning value.
#
# This file documents an approach we explored and why we abandoned it, along
# with the Nix evaluation findings we discovered along the way.
#
#
# == The approach: mkDirLinks ==
#
# The goal was to auto-generate home.file entries for every file/symlink in
# dotfiles/claude/, so adding a file there would wire it to ~/.claude/ on the
# next rebuild without touching any Nix files.
#
#   mkDirLinks = src: dest:
#     lib.mapAttrs'
#       (name: _: {
#         name = "${dest}/${name}";
#         value.source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/${src}/${name}";
#       })
#       (lib.filterAttrs (_: t: t == "regular" || t == "symlink")
#         (builtins.readDir "${dotfilesDir}/${src}"));
#
# mapAttrs vs mapAttrs':
#   mapAttrs  :: (name -> value -> newValue) -> attrset -> attrset   -- keys unchanged
#   mapAttrs' :: (name -> value -> { name; value; }) -> attrset -> attrset  -- keys renamed
# We need mapAttrs' because input keys are bare filenames ("statusline-command.sh")
# but output keys must be home-manager paths (".claude/statusline-command.sh").
# `value.source` in the closure body is dotted attrset syntax for the output
# record, NOT a reference to the `value` function argument (which is `_`).
#
#
# == Why a separate file was needed ==
#
# Nix can merge two attrset *literals* assigned to the same key in the same file
# because their sub-keys are statically visible at parse time:
#
#   { home.file = { "fish" = ...; }; home.file = { "ur mom" = ...; }; }  -- OK
#
# But a function application is opaque to that static analysis — Nix rejects it
# before evaluating anything, regardless of what the function returns:
#
#   { home.file = { "fish" = ...; }; home.file = mkDirLinks ...; }  -- ERROR
#
# Across separate module files the module system intercepts before this check
# runs. Each file is evaluated into its own independent attrset; the module
# system then collects all of them, recognises home.file as attrsOf submodule
# (a mergeable type), and unions the results using that type's merge function —
# the same mechanism that lets 40 NixOS modules all append to
# environment.systemPackages without knowing about each other.
#
#
# == Why we abandoned mkDirLinks ==
#
# builtins.readDir runs at eval time and requires reading the live filesystem.
# Flakes evaluate in pure mode, which forbids access to absolute paths outside
# the Nix store:
#
#   error: access to absolute path '/home/yztangent/.home/dotfiles/claude'
#          is forbidden in pure evaluation mode (use '--impure' to override)
#
# The alternatives were:
#   1. --impure on every nixos-rebuild — dirty, defeats flake purity
#   2. inputs.self + "/dotfiles/claude" for readDir — reads the git-committed
#      snapshot, not the live directory; uncommitted files would be invisible,
#      and mkOutOfStoreSymlink would still need the live path for targets
#   3. home.activation script — runs on the live machine post-build, sidesteps
#      pure eval, but is a different mental model from the rest of the config
#
# We went with the simplest correct solution instead: symlink ~/.claude to
# dotfiles/claude/ the same way opencode does, and use a .gitignore inside
# dotfiles/claude/ to ignore everything Claude Code writes at runtime, while
# whitelisting the specific files we own (CLAUDE.md, statusline-command.sh,
# skills).

{ config, lib, ... }:

let
  dotfilesDir = "${config.home.homeDirectory}/.home/dotfiles";

  mkDirLinks = src: dest:
    lib.mapAttrs'
      (name: _: {
        name = "${dest}/${name}";
        value.source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/${src}/${name}";
      })
      (lib.filterAttrs (_: t: t == "regular" || t == "symlink")
        (builtins.readDir "${dotfilesDir}/${src}"));
in
{
  home.file = mkDirLinks "claude" ".claude";
}

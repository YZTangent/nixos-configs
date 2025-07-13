# /etc/nixos/modules/neovim.nix
{ inputs, pkgs, ... }:

{
  programs.nixvim = {
    enable = true;
    extraPlugins = with pkgs.vimPlugins; [
      # Add any extra plugins you want here
    ];
    # Import the LazyVim starter
    # You can find more starters or create your own:
    # https://github.com/nix-community/nixvim/blob/main/starters/README.md
    import = inputs.nixvim.templates.LazyVim;
  };
}

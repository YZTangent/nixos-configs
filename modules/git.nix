# /etc/nixos/modules/git.nix
{ ... }:

{
  programs.git = {
    enable = true;
    userName = "YZTangent";
    userEmail = "yuanzheng.tan.tyz@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
    };
  };
}

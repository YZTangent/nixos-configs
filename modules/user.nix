{ pkgs, ... }:

{
  users.users.yztangent = {
    isNormalUser = true;
    description = "YZTangent";
    extraGroups = [ "networkmanager" "wheel" "dialout" "docker" ];
    shell = pkgs.fish;
  };
}

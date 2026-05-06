{ pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    brightnessctl
    telegram-desktop
    discord
    swaybg
    starship
    btop
    alacritty
    waybar
    swaylock
    (inputs.zen-browser.packages."${pkgs.stdenv.hostPlatform.system}".default.override {
      nativeMessagingHosts = [ pkgs.firefoxpwa ];
    })
  ];
}

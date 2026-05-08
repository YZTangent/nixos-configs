{ pkgs, ... }:

{
  time.timeZone = "Asia/Singapore";

  fonts.packages = with pkgs; [ noto-fonts-cjk-sans noto-fonts-cjk-serif ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [ kdePackages.fcitx5-chinese-addons fcitx5-gtk ];
  };

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}

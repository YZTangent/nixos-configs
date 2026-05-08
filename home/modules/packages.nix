{ pkgs, inputs, ... }:

let
  # Languages & toolchains
  rust = [ pkgs.rustup ];
  go = [ pkgs.go ];
  c_cpp = with pkgs; [ gnumake cmake clang clang-tools pkg-config ];
  gamedev = with pkgs; [ godot ];

  # Desktop environment
  desktop = with pkgs; [ brightnessctl swaybg waybar swaylock ];

  # Terminal Enumlator
  termimal = with pkgs; [ alacritty ghostty ];

  # Messaging
  messaging = with pkgs; [ telegram-desktop discord ];

  # Shell & system tools
  shell = with pkgs; [ starship btop ];

  # AI assistants
  ai = with pkgs; [ gemini-cli claude-code opencode ];

  # CAD
  cad = with pkgs; [ openscad ];

  # Browsers
  browsers = [
    (inputs.zen-browser.packages."${pkgs.stdenv.hostPlatform.system}".default.override {
      nativeMessagingHosts = [ pkgs.firefoxpwa ];
    })
  ];
in
{
  home.packages =
    desktop ++
    termimal ++
    messaging ++
    shell ++
    rust ++ go ++ c_cpp ++ gamedev ++
    ai ++
    cad ++
    browsers;

  programs.eza.enable = true;
  programs.zoxide.enable = true;
  programs.fuzzel.enable = true;
}

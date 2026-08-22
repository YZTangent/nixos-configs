{ pkgs, inputs, ... }:

let
  # Languages & toolchains
  rust = [ pkgs.rustup ];
  go = [ pkgs.go ];
  c_cpp = with pkgs; [ gnumake cmake clang clang-tools pkg-config ];
  gamedev = with pkgs; [ godot ];
  research  = with pkgs; [ marimo ];

  # Desktop environment
  desktop = with pkgs; [ brightnessctl swaybg waybar swaylock ];

  # Terminal Enumlator
  termimal = with pkgs; [ alacritty ghostty ];

  # Messaging
  messaging = with pkgs; [ telegram-desktop discord ];

  # Shell & system tools
  shell = with pkgs; [ starship btop ];

  # AI assistants
  ai = with pkgs; [ 
    claude-code
    opencode
    lmstudio
    codex
  ];

  ai-llm-agents = with inputs.llm-agents.packages."${pkgs.stdenv.hostPlatform.system}"; [
    antigravity-cli
    pi
    omp
    dsh
  ];

  # AI agent tools
  code-memory = with inputs.llm-agents.packages."${pkgs.stdenv.hostPlatform.system}"; [
    # gitnexus
    # codegraph
  ];

  # AI agent tools
  ai-tools = with inputs.llm-agents.packages."${pkgs.stdenv.hostPlatform.system}"; [
    ccusage
  ];


  # CAD
  cad = with pkgs; [
    orca-slicer
    blender
    openscad
  ];

  # Browsers
  browsers = [
    (inputs.zen-browser.packages."${pkgs.stdenv.hostPlatform.system}".default.override {
      nativeMessagingHosts = [ pkgs.firefoxpwa ];
    })
  ];

  # Art
  art = with pkgs; [ krita ];
in
{
  home.packages =
    desktop ++
    termimal ++
    messaging ++
    shell ++
    rust ++ go ++ c_cpp ++ gamedev ++
    research ++
    cad ++
    browsers ++
    ai ++
    ai-llm-agents ++
    ai-tools ++
    art ++
    code-memory;

  programs.eza.enable = true;
  programs.zoxide.enable = true;
  programs.fuzzel.enable = true;
}

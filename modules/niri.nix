{ config, pkgs, ... }:

{
  # Enable Niri as your Wayland compositor
  services.niri.enable = true;

  # Niri specific configuration options
  xdg.configFile."niri/config.kdl".text = ''
    #
    # Niri Configuration File (config.kdl)
    #
    # This file is managed by Home Manager.
    # For more details, see Niri's documentation and Home Manager's Niri module.
    #

    # Define your workspaces with custom names
    # Niri uses 0-indexed workspaces by default, but you can map them to names.
    # These names will be displayed in your status bar if supported (e.g., Waybar).
    workspace "code" {
        # You can optionally set initial commands or properties for this workspace
        # For example, to open a terminal on this workspace:
        # startup_command "alacritty"
    }
    workspace "browser" {}
    workspace "notes" {}
    workspace "chat" {}

    # Global keybindings
    # Modifiers: "Super" (Windows/Meta key), "Alt", "Control", "Shift"
    # Keys are typically lowercase letters or standard key names (e.g., "Return", "Space", "Tab")

    # Window Management
    keybinding "Super-Return" {
        command "spawn alacritty" # Spawn a terminal
    }
    keybinding "Super-d" {
        command "spawn wofi --show drun" # Spawn an application launcher (e.g., wofi)
    }
    keybinding "Super-q" {
        command "close" # Close the focused window
    }

    # Consume and Expel (Moving windows between parent/child groups)
    # 'consume' moves the focused window into the current group as a child.
    # 'expel' moves the focused window out of its current group to its parent.
    keybinding "Super-c" {
        command "consume"
    }
    keybinding "Super-e" {
        command "expel"
    }

    # Moving between windows (left/right, up/down within the current group)
    # Niri's movement commands are relative to the current layout.
    # For a horizontal layout, "left" and "right" move between windows.
    # For a vertical layout, "up" and "down" move between windows.
    # You might need to adjust these based on your preferred layout.
    keybinding "Super-h" {
        command "focus_direction left" # Focus window to the left
    }
    keybinding "Super-l" {
        command "focus_direction right" # Focus window to the right
    }
    keybinding "Super-k" {
        command "focus_direction up"    # Focus window upwards
    }
    keybinding "Super-j" {
        command "focus_direction down"  # Focus window downwards
    }

    # Moving windows
    keybinding "Super-Shift-h" {
        command "move_direction left" # Move window to the left
    }
    keybinding "Super-Shift-l" {
        command "move_direction right" # Move window to the right
    }
    keybinding "Super-Shift-k" {
        command "move_direction up"    # Move window upwards
    }
    keybinding "Super-Shift-j" {
        command "move_direction down"  # Move window downwards
    }

    # Workspace Navigation
    # These keybindings allow you to switch directly to your named workspaces.
    keybinding "Super-1" { command "workspace code" }
    keybinding "Super-2" { command "workspace browser" }
    keybinding "Super-3" { command "workspace notes" }
    keybinding "Super-4" { command "workspace chat" }

    # Move window to a specific workspace
    keybinding "Super-Shift-1" { command "move_to_workspace code" }
    keybinding "Super-Shift-2" { command "move_to_workspace browser" }
    keybinding "Super-Shift-3" { command "move_to_workspace notes" }
    keybinding "Super-Shift-4" { command "move_to_workspace chat" }

    # Border color of the highlighted window
    # You can specify colors using hex codes, RGB, or named colors.
    # Niri uses a focus_color and unfocus_color.
    # The 'focus_color' is for the currently highlighted (focused) window.
    # The 'unfocus_color' is for other windows.
    focus_color "rgb(255, 165, 0)" # Orange color for focused window
    unfocus_color "rgb(60, 60, 60)" # Dark grey for unfocused windows
    border_width 3 # Set border width for visibility

    # Other useful Niri settings (optional)
    # You can add more settings here as needed.
    # For example, to set the default layout:
    # default_layout "horizontal"
    # Or to enable gaps between windows:
    # gap 10
  '';
}


# Ghostty Config

## Summary

Create a minimal Ghostty terminal emulator config based on the existing Alacritty config, and register it into home-manager for symlinking.

## Alacritty Baseline

File: `dotfiles/alacritty/alacritty.toml`

```toml
[window]
padding = { x = 0, y = 0 }
decorations = "None"
opacity = 0.8

[font]
normal = { family = "JetBrainsMono Nerd Font" }
size = 9.0
```

## Ghostty Config Mapping

File: `dotfiles/ghostty/config`

| Alacritty | Ghostty | Notes |
|-----------|---------|-------|
| `font.normal.family` | `font-family = JetBrainsMono Nerd Font` | Same font |
| `font.size = 9.0` | `font-size = 9` | Same size |
| `window.opacity = 0.8` | `background-opacity = 0.8` | Same opacity |
| `window.decorations = "None"` | `window-decoration = false` | No title bar |
| `window.padding = { x = 0, y = 0 }` | *(omitted)* | User requested no padding config |

## Home-Manager Changes

- **File to create:** `dotfiles/ghostty/config`
- **File to edit:** `home/modules/dotfiles.nix` — add symlink entry for `~/.config/ghostty/config`
- **No change needed:** `home/modules/packages.nix` — `ghostty` already installed

## Changes

1 new file, 1 modified.

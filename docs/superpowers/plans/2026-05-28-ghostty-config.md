# Ghostty Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a minimal ghostty config based on the existing alacritty config and register it in home-manager.

**Architecture:** Single config file `dotfiles/ghostty/config` symlinked into `~/.config/ghostty/config` via the existing dotfiles.nix module. Ghostty is already installed as a package.

**Tech Stack:** Nix home-manager, ghostty config format (`key = value`)

---

### Task 1: Create ghostty config file

**Files:**
- Create: `dotfiles/ghostty/config`

- [ ] **Step 1: Create the ghostty config**

Write `dotfiles/ghostty/config`:
```
font-family = JetBrainsMono Nerd Font
font-size = 9
background-opacity = 0.8
window-decoration = false
```

### Task 2: Register ghostty config in dotfiles.nix

**Files:**
- Modify: `home/modules/dotfiles.nix` (add entry after alacritty)

- [ ] **Step 1: Add symlink entry**

Insert after the alacritty block:
```nix
  home.file.".config/ghostty" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/ghostty";
    recursive = true;
  };
```

### Task 3: Verify with home-manager build

- [ ] **Step 1: Run home-manager build**

Run: `home-manager build`
Expected: builds successfully with no errors

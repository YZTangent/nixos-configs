#!/usr/bin/env bash

# Read JSON from stdin
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .workspace.currentDir // .cwd // ""')
[ -z "$cwd" ] && cwd=$PWD
cwd_display="${cwd/#$HOME/~}"

git_branch=$(echo "$input" | jq -r '.vcs.branch // ""')
if [ -z "$git_branch" ] || [ "$git_branch" = "null" ]; then
  if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" -c core.useBuiltinFSMonitor=false symbolic-ref --short HEAD 2>/dev/null ||
      git -C "$cwd" -c core.useBuiltinFSMonitor=false rev-parse --short HEAD 2>/dev/null)
  fi
fi

model_name=$(echo "$input" | jq -r '.model.display_name // .model.id // "Unknown Model"')

# Get mode from settings.json
settings_file="$HOME/.gemini/antigravity-cli/settings.json"
mode="Review"
if [ -f "$settings_file" ]; then
  perm=$(jq -r '.toolPermission // ""' "$settings_file")
  if [ "$perm" = "always-proceed" ]; then
    mode="YOLO"
  elif [ "$perm" = "strict" ]; then
    mode="Strict"
  fi
fi

ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // .context.usedPercentage // 0')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // .context.size // 0')

gemini_5h_rem=$(echo "$input" | jq -r '.quota["gemini-5h"].remaining_fraction // 1')
gemini_wk_rem=$(echo "$input" | jq -r '.quota["gemini-weekly"].remaining_fraction // 1')
gem_5h_pct=$(awk -v rem="$gemini_5h_rem" 'BEGIN { printf "%d", (1.0 - rem) * 100 }')
gem_wk_pct=$(awk -v rem="$gemini_wk_rem" 'BEGIN { printf "%d", (1.0 - rem) * 100 }')

p3_5h_rem=$(echo "$input" | jq -r '.quota["3p-5h"].remaining_fraction // 1')
p3_wk_rem=$(echo "$input" | jq -r '.quota["3p-weekly"].remaining_fraction // 1')
p3_5h_pct=$(awk -v rem="$p3_5h_rem" 'BEGIN { printf "%d", (1.0 - rem) * 100 }')
p3_wk_pct=$(awk -v rem="$p3_wk_rem" 'BEGIN { printf "%d", (1.0 - rem) * 100 }')

make_bar() {
  local pct=$1 width=${2:-16}
  local filled=$((pct * width / 100))
  local empty=$((width - filled))
  local bar="["
  for ((i = 0; i < filled; i++)); do bar+="█"; done
  for ((i = 0; i < empty; i++)); do bar+="░"; done
  bar+="]"
  printf '%s' "$bar"
}

color_for_pct() {
  local pct=$1
  if [ "$pct" -ge 80 ]; then
    printf '\033[31m' # red
  elif [ "$pct" -ge 50 ]; then
    printf '\033[33m' # yellow
  else
    printf '\033[32m' # green
  fi
}

RESET="\033[0m"
BOLD="\033[1m"
CYAN="\033[36m"
YELLOW="\033[33m"
DIM="\033[2m"
SEP="${DIM} │ ${RESET}"

ctx_int=${ctx_pct%.*}
ctx_int=${ctx_int:-0}
ctx_color=$(color_for_pct "$ctx_int")

gem_5h_color=$(color_for_pct "$gem_5h_pct")
gem_wk_color=$(color_for_pct "$gem_wk_pct")
p3_5h_color=$(color_for_pct "$p3_5h_pct")
p3_wk_color=$(color_for_pct "$p3_wk_pct")

pad_label() {
  printf "%-9s" "$1"
}
pad_pct() {
  printf "%4s" "${1}%"
}

out=""

# Line 1: cwd, git branch, model name, and mode
out+="$(printf "${CYAN}${BOLD}%s${RESET}" "$cwd_display")"
[ -n "$git_branch" ] && out+=" $(printf "${YELLOW}(%s)${RESET}" "$git_branch")"
out+="$SEP"
out+="${DIM}${model_name}${RESET}$SEP"
if [ "$mode" = "YOLO" ]; then
  out+="${BOLD}\033[31m${mode}${RESET}\n"
else
  out+="${DIM}${mode}${RESET}\n"
fi

# Line 2: Context Window
ctx_label=$(pad_label "Context")
out+="${DIM}${ctx_label}${RESET}$SEP"
if [ "$ctx_size" -gt 0 ]; then
  ctx_k=$((ctx_size / 1000))
  out+="${ctx_color}$(make_bar "$ctx_int" 29)${RESET} ${ctx_color}$(pad_pct "$ctx_int")${RESET}${DIM}/${ctx_k}K${RESET}\n"
else
  out+="${ctx_color}$(make_bar "$ctx_int" 29)${RESET} ${ctx_color}$(pad_pct "$ctx_int")${RESET}\n"
fi

# Line 3: Gemini quotas
gem_label=$(pad_label "Gemini")
out+="${DIM}${gem_label}${RESET}$SEP"
out+="${DIM}5h${RESET} ${gem_5h_color}$(make_bar "$gem_5h_pct" 12)${RESET} ${gem_5h_color}$(pad_pct "$gem_5h_pct")${RESET}$SEP"
out+="${DIM}wk${RESET} ${gem_wk_color}$(make_bar "$gem_wk_pct" 12)${RESET} ${gem_wk_color}$(pad_pct "$gem_wk_pct")${RESET}\n"

# Line 4: 3rd Party quotas
p3_label=$(pad_label "3rd Party")
out+="${DIM}${p3_label}${RESET}$SEP"
out+="${DIM}5h${RESET} ${p3_5h_color}$(make_bar "$p3_5h_pct" 12)${RESET} ${p3_5h_color}$(pad_pct "$p3_5h_pct")${RESET}$SEP"
out+="${DIM}wk${RESET} ${p3_wk_color}$(make_bar "$p3_wk_pct" 12)${RESET} ${p3_wk_color}$(pad_pct "$p3_wk_pct")${RESET}"

printf "%b\n" "$out"

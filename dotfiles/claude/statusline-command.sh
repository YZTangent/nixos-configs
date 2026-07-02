#!/usr/bin/env bash
# Claude Code status line: context window bar, 5hr usage, weekly usage

# Tune these to your plan's actual limits
FIVE_HR_LIMIT=45
WEEKLY_LIMIT=250

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model_name=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')

cwd_display="${cwd/#$HOME/~}"

git_branch=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" -c core.useBuiltinFSMonitor=false symbolic-ref --short HEAD 2>/dev/null \
        || git -C "$cwd" -c core.useBuiltinFSMonitor=false rev-parse --short HEAD 2>/dev/null)
fi

# Count user turns from history (proxy for AI responses / rate limit usage)
HISTORY="$HOME/.claude/history.jsonl"
now_ms=$(date +%s%3N)
five_hr_ms=$(( now_ms - 5 * 3600 * 1000 ))
week_ms=$(( now_ms - 7 * 24 * 3600 * 1000 ))
five_hr_count=0
week_count=0
if [ -f "$HISTORY" ]; then
    read -r five_hr_count week_count <<< "$(awk -v fh="$five_hr_ms" -v wk="$week_ms" '
        match($0, /"timestamp":([0-9]+)/, a) {
            ts = a[1]+0
            if (ts >= wk) { wk_n++ }
            if (ts >= fh) { fh_n++ }
        }
        END { print fh_n+0, wk_n+0 }
    ' "$HISTORY")"
fi

make_bar() {
    local pct=$1 width=${2:-16}
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar="["
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    bar+="]"
    printf '%s' "$bar"
}

color_for_pct() {
    local pct=$1
    if   [ "$pct" -ge 80 ]; then printf '\033[31m'   # red
    elif [ "$pct" -ge 50 ]; then printf '\033[33m'   # yellow
    else                         printf '\033[32m'   # green
    fi
}

RESET="\033[0m"
BOLD="\033[1m"
CYAN="\033[36m"
YELLOW="\033[33m"
DIM="\033[2m"
SEP="${DIM} │ ${RESET}"

used_int=${used_pct%.*}; used_int=${used_int:-0}
five_hr_pct=$(( five_hr_count * 100 / FIVE_HR_LIMIT ))
week_pct=$(( week_count * 100 / WEEKLY_LIMIT ))
[ "$five_hr_pct" -gt 100 ] && five_hr_pct=100
[ "$week_pct"    -gt 100 ] && week_pct=100

ctx_color=$(color_for_pct "$used_int")
fh_color=$(color_for_pct "$five_hr_pct")
wk_color=$(color_for_pct "$week_pct")

window_k=$(( window_size / 1000 ))

out=""
[ -n "$model_name" ] && out+="$(printf "${DIM}[%s]${RESET}" "$model_name")$SEP"
out+="$(printf "${CYAN}${BOLD}%s${RESET}" "$cwd_display")"
[ -n "$git_branch" ] && out+=" $(printf "${YELLOW}(%s)${RESET}" "$git_branch")"

out+="$SEP"
out+="${DIM}ctx${RESET} ${ctx_color}$(make_bar "$used_int")${RESET} ${ctx_color}${used_int}%${RESET}${DIM}/${window_k}K${RESET}"

out+="$SEP"
out+="${DIM}5h${RESET} ${fh_color}$(make_bar "$five_hr_pct" 12)${RESET} ${fh_color}${five_hr_count}/${FIVE_HR_LIMIT}${RESET}"

out+="$SEP"
out+="${DIM}wk${RESET} ${wk_color}$(make_bar "$week_pct" 12)${RESET} ${wk_color}${week_count}/${WEEKLY_LIMIT}${RESET}"

printf "%b\n" "$out"

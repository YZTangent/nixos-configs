# Fish color configuration (ayu mirage theme)
set -U fish_color_autosuggestion 707A8C
set -U fish_color_comment 5C6773
set -U fish_color_cwd 73D0FF
set -U fish_color_end F29E74
set -U fish_color_escape 95E6CB
set -U fish_color_match F28779
set -U fish_color_normal CBCCC6
set -U fish_color_operator FFCC66
set -U fish_color_param CBCCC6
set -U fish_color_quote BAE67E
set -U fish_color_redirection D4BFFF
set -U fish_color_search_match --background FFCC66
set -U fish_color_selection FFCC66

# Prompt item colors
set -U fish_color_cancel 1F2430
set -U fish_color_host D4BFFF
set -U fish_color_host_remote D4BFFF
set -U fish_color_user FFA759

# Command and error colors
set -U fish_color_command green --bold
set -U fish_color_error red --bold

# Disable greeting
set fish_greeting

# Shell abbreviations
abbr ls eza
abbr ll eza -l
abbr la eza -a
abbr v nvim
abbr fcopy fish_clipboard_copy
abbr fpaste fish_clipboard_paste

# Starship prompt
starship init fish | source

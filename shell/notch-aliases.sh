# Shell helpers managed by xt9y/notch-quickshell.
# This file is sourced from ~/.bashrc by scripts/apply-hypr.sh.

alias config-update='cd "$HOME/.config/quickshell/notch" && git pull && setsid -f qs -c notch >/dev/null 2>&1'

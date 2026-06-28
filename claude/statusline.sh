#!/usr/bin/env bash
# Claude Code statusline. Reads the Claude JSON payload on stdin and prints:
#   [HH:MM:SS UTC] <dir> (<branch>*+ ⇡N⇣N) · <Model>
# where  *  = unstaged changes, + = staged, ⇡N/⇣N = ahead/behind upstream.
# Segment colors mirror the zsh prompt style (zsh.sh): dim gray meta, cyan dir,
# magenta branch, blue ahead/behind.
set -u

# ANSI colors
GRAY='\033[90m'      # dim gray — time / separators
CYAN='\033[36m'      # cyan     — dir
MAGENTA='\033[35m'   # magenta  — branch + dirty flags
BLUE='\033[34m'      # blue     — ahead/behind
RESET='\033[0m'

# Claude streams its status payload (JSON) on stdin.
payload="$(cat)"

dir=""
model=""
if command -v jq >/dev/null 2>&1; then
  dir="$(printf '%s' "$payload" | jq -r '.workspace.current_dir // empty' 2>/dev/null)"
  model="$(printf '%s' "$payload" | jq -r '.model.display_name // empty' 2>/dev/null)"
fi
dir="${dir:-$PWD}"
model="${model:-Claude}"

# UTC clock (works on both BSD/macOS and GNU/Linux date).
now="$(date -u +%H:%M:%S)"

# Directory label: ~ for $HOME, otherwise the basename.
case "$dir" in
  "$HOME") disp='~' ;;
  *)       disp="$(basename "$dir")" ;;
esac

# Git segment, computed from the workspace dir.
git_seg=""
if branch="$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null)" \
   || branch="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)"; then
  # Dirty flags: * unstaged, + staged.
  flags=""
  git -C "$dir" diff --quiet --ignore-submodules 2>/dev/null        || flags="${flags}*"
  git -C "$dir" diff --cached --quiet --ignore-submodules 2>/dev/null || flags="${flags}+"

  # Ahead/behind vs upstream.
  ab=""
  if upstream="$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)"; then
    counts="$(git -C "$dir" rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null)"
    behind="${counts%%[!0-9]*}"
    ahead="${counts##*[!0-9]}"
    [ "${ahead:-0}" -gt 0 ] 2>/dev/null  && ab="${ab}⇡${ahead}"
    [ "${behind:-0}" -gt 0 ] 2>/dev/null && ab="${ab}⇣${behind}"
  fi

  git_seg=" (${MAGENTA}${branch}${flags}${RESET}"
  [ -n "$ab" ] && git_seg="${git_seg} ${BLUE}${ab}${RESET}"
  git_seg="${git_seg})"
fi

printf '%b\n' "${GRAY}[${now} UTC]${RESET} ${CYAN}${disp}${RESET}${git_seg} ${GRAY}·${RESET} ${model}"

# Dotfiles — sourced into every env's interactive shell.
# Kept POSIX-ish so it works under both bash and zsh.

# 0) If the client terminal's terminfo isn't installed here (e.g. ghostty,
#    kitty), line editing breaks badly under zsh — fall back to a definition
#    every box has. (zsh re-inits the terminal when TERM is assigned.)
if command -v infocmp >/dev/null 2>&1 && ! infocmp "${TERM:-dumb}" >/dev/null 2>&1; then
  export TERM=xterm-256color
fi

# 1) Land in your workspace instead of $HOME on SSH / remote login.
#    Some remote envs drop you in $HOME. Set WORKSPACE_DIR to your workspace
#    root to opt in (left disabled if unset). Handles both layouts:
#      - a single repo AT $WORKSPACE_DIR        (cd straight in)
#      - many repos under $WORKSPACE_DIR/<repo>/ (cd into the first one)
#    Point WORKSPACE_DIR directly at a sub-repo if you want a specific one.
if [ -n "${WORKSPACE_DIR:-}" ] && [ -d "$WORKSPACE_DIR" ] && [ "$PWD" = "$HOME" ]; then
  if [ -e "$WORKSPACE_DIR/.git" ] || [ -f "$WORKSPACE_DIR/go.mod" ]; then
    cd "$WORKSPACE_DIR"
  else
    __ws_src=$(ls -d "$WORKSPACE_DIR"/*/ 2>/dev/null | head -1)
    [ -n "$__ws_src" ] && cd "$__ws_src"
    unset __ws_src
  fi
fi

# 2) Ensure the Go toolchain + local bins are on PATH.
#    Go often ships at /usr/local/go/bin but isn't always on PATH.
for __d in /usr/local/go/bin "$HOME/go/bin" "$HOME/.local/bin" \
           "$HOME/.nix-profile/bin" /nix/var/nix/profiles/default/bin; do
  case ":$PATH:" in
    *":$__d:"*) ;;
    *) [ -d "$__d" ] && PATH="$PATH:$__d" ;;
  esac
done
export PATH
unset __d

# 3) Quality-of-life aliases (safe everywhere)
alias ll='ls -alh'
alias la='ls -A'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -20'
alias gb='git branch'
alias gco='git checkout'

# 4) Make grep/less friendlier
export LESS='-FRX'

# 5) Shell prompt (bash only; zsh.sh inits starship for zsh). Both shells read
#    ~/.config/starship.toml — installed by install.sh on remote envs.
if [ -n "${BASH_VERSION:-}" ] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

#!/usr/bin/env bash
# Dotfiles installer. Idempotent — safe to re-run on every env boot.
# Clone this repo to ~/.dotfiles and run this script with DOTFILES_DIR set.
set -eu

DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
SRC="$DIR/shell.sh"

# 0) Some callers run this under a short-lived context and SIGKILL whatever is
#    still running after a few seconds — far less than apt + nix need. Re-exec
#    detached (own session, immune to the caller's kill) and return immediately.
if [ "${DOTFILES_DETACHED:-}" != "1" ] && command -v setsid >/dev/null 2>&1; then
  DOTFILES_DETACHED=1 DOTFILES_DIR="$DIR" setsid nohup bash "$DIR/install.sh" \
    >>"$HOME/.dotfiles-install.log" 2>&1 </dev/null &
  echo "dotfiles: install continuing in background (log: ~/.dotfiles-install.log)"
  exit 0
fi

# 1) Source shell.sh from every shell rc (idempotent — never duplicates the line).
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
  touch "$rc"
  if ! grep -qF "$SRC" "$rc" 2>/dev/null; then
    printf '\n# dotfiles\n[ -f "%s" ] && . "%s"\n' "$SRC" "$SRC" >> "$rc"
  fi
done

# 2) Install nix packages from packages.txt (one nixpkgs attr per line; '#' = comment).
#    Requires Determinate Nix (or any nix with `nix profile install`) on PATH.
#    Skips already-installed packages so re-boots are fast.
#    This script runs outside a login shell, so nix may not be on PATH yet —
#    source its profile script first.
if ! command -v nix >/dev/null 2>&1 && [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
PKGS="$DIR/packages.txt"
if command -v nix >/dev/null 2>&1 && [ -f "$PKGS" ]; then
  installed="$(nix profile list 2>/dev/null || true)"
  while IFS= read -r line; do
    pkg="${line%%#*}"                       # strip trailing comment
    pkg="$(printf '%s' "$pkg" | tr -d '[:space:]')"
    [ -z "$pkg" ] && continue
    if printf '%s\n' "$installed" | grep -q "nixpkgs#${pkg}\$"; then
      continue                              # already installed
    fi
    echo "nix: installing $pkg"
    nix profile install "nixpkgs#${pkg}" 2>&1 || echo "nix: WARN could not install $pkg (continuing)"
  done < "$PKGS"
fi

# 3) zsh: install + plugins (Debian/apt hosts with passwordless sudo only),
#    source zsh.sh from .zshrc, and make zsh the login shell.
if command -v apt-get >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  if ! command -v zsh >/dev/null 2>&1; then
    sudo apt-get update -qq
    # force-confdef/confold: never prompt on conffile conflicts (the base image
    # may ship its own /etc/zsh/zshrc, which otherwise hangs a headless install)
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
      zsh zsh-autosuggestions zsh-syntax-highlighting
  fi
  zsh_path="$(command -v zsh || true)"
  login_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
  if [ -n "$zsh_path" ] && [ "$login_shell" != "$zsh_path" ]; then
    sudo chsh -s "$zsh_path" "$(id -un)"
  fi
fi

ZSRC="$DIR/zsh.sh"
touch "$HOME/.zshrc"
if ! grep -qF "$ZSRC" "$HOME/.zshrc" 2>/dev/null; then
  printf '\n# dotfiles (zsh-only)\n[ -f "%s" ] && . "%s"\n' "$ZSRC" "$ZSRC" >> "$HOME/.zshrc"
fi

# 4) Claude Code: install the statusline and register it in settings.json.
#    jq-MERGE the statusLine key (don't overwrite the file) so env-provisioned
#    keys — session hooks, telemetry, etc. — survive. Skipped if jq is absent.
if command -v jq >/dev/null 2>&1; then
  mkdir -p "$HOME/.claude"
  cp "$DIR/claude/statusline.sh" "$HOME/.claude/statusline.sh"
  chmod +x "$HOME/.claude/statusline.sh"
  SETTINGS="$HOME/.claude/settings.json"
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
  tmp="$(mktemp)"
  if jq --arg cmd '$HOME/.claude/statusline.sh' \
        '.statusLine = {type: "command", command: $cmd}' \
        "$SETTINGS" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$SETTINGS"
  else
    rm -f "$tmp"                              # leave a malformed settings.json untouched
  fi
fi

# 5) Remote-env extras: install the shell prompt config + merge the remote
#    Claude settings. Opt in by exporting DOTFILES_REMOTE=1 in your env, so this
#    never touches a local Mac / plain Linux box. If WORKSPACE_DIR is set, a
#    Read() permission for it is added to the allow list.
if [ "${DOTFILES_REMOTE:-}" = "1" ] && command -v jq >/dev/null 2>&1; then
  mkdir -p "$HOME/.claude" "$HOME/.config"
  cp "$DIR/starship.toml" "$HOME/.config/starship.toml"   # shell prompt: UTC + dir + branch

  SETTINGS="$HOME/.claude/settings.json"
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
  # Grant read access to the workspace, if one is configured.
  workspace_allow='[]'
  if [ -n "${WORKSPACE_DIR:-}" ]; then
    workspace_allow="$(printf '["Read(%s/**)"]' "$WORKSPACE_DIR")"
  fi
  tmp="$(mktemp)"
  # Deep-merge the fragment (scalar keys win); union permissions.allow so
  # env-provisioned keys (hooks/telemetry) and any existing allow entries survive.
  if jq -s --argjson ws "$workspace_allow" '
        .[0] as $cur | .[1] as $frag |
        ($cur * $frag)
        | .permissions.allow =
            ((($cur.permissions.allow // []) + ($frag.permissions.allow // []) + $ws) | unique)
      ' "$SETTINGS" "$DIR/claude/settings.linux.json" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$SETTINGS"
  else
    rm -f "$tmp"                              # leave a malformed settings.json untouched
  fi
fi

echo "dotfiles installed (shell.sh + zsh.sh + nix packages from packages.txt)"

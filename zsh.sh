# Dotfiles — zsh-only config, sourced from ~/.zshrc (bash never reads this).

# Tab-completion
autoload -Uz compinit && compinit

command -v zoxide   >/dev/null && eval "$(zoxide init zsh)"
command -v starship >/dev/null && eval "$(starship init zsh)"
command -v atuin    >/dev/null && eval "$(atuin init zsh)"

# Plugin locations: Homebrew (macOS), apt (/usr/share), nix profile.
for __dir in "${HOMEBREW_PREFIX:-/opt/homebrew}/share" /usr/share "$HOME/.nix-profile/share"; do
  if [ -f "$__dir/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$__dir/zsh-autosuggestions/zsh-autosuggestions.zsh"
    break
  fi
done
# syntax-highlighting must be sourced last
for __dir in "${HOMEBREW_PREFIX:-/opt/homebrew}/share" /usr/share "$HOME/.nix-profile/share"; do
  if [ -f "$__dir/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$__dir/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    break
  fi
done
unset __dir

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#ffffff,bold'

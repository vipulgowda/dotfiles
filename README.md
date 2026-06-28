# dotfiles

Minimal dotfiles for remote dev environments — optionally auto-`cd` into your
workspace on login, plus a handful of quality-of-life shell aliases, a starship
prompt, and a Claude Code statusline.

On every env boot this repo is cloned to `~/.dotfiles` and `install.sh` runs.
`install.sh` idempotently makes every shell rc (`.bashrc`, `.zshrc`, `.profile`)
source `shell.sh`, so re-running it never duplicates lines. It also installs the
nix packages listed in `packages.txt`.

## Configuration

Two optional environment variables control behavior; both default to off, so a
fresh clone is inert until you opt in (set them in your env / platform env config):

| Variable | Effect |
| --- | --- |
| `WORKSPACE_DIR` | On login, `cd` into this directory instead of `$HOME`. Point it at a single repo to land in it, or at a parent dir to land in its first sub-repo. |
| `DOTFILES_REMOTE=1` | Enable the remote-env extras: install the starship prompt config and merge the remote Claude Code settings. Leave unset on local machines. |

## What `shell.sh` does
- **Auto-`cd` into `WORKSPACE_DIR`** on login (if set), so SSH / editor sessions
  don't dump you in `$HOME`.
- **Git aliases:** `gs` (status), `gd` (diff), `gl` (log, last 20 oneline),
  `gb` (branch), `gco` (checkout).
- **`ls` aliases:** `ll` (`ls -alh`), `la` (`ls -A`).
- **Friendlier pager:** `LESS=-FRX` so short output isn't paged and colors pass through.
- **PATH:** adds the Go toolchain and common local bin dirs if present.
- **TERM fallback:** falls back to `xterm-256color` if the client's terminfo is missing.

## What `zsh.sh` does (zsh shells only)
- `install.sh` installs zsh + zsh-autosuggestions + zsh-syntax-highlighting (apt) and
  makes zsh the login shell, so SSH sessions land in zsh.
- `zsh.sh` is sourced from `.zshrc` only: tab-completion (`compinit`), ghost-text
  autosuggestions, syntax highlighting, and starship / zoxide / atuin inits (installed
  via `packages.txt`; each is skipped if absent).
- Works on macOS too (Homebrew plugin paths are detected) — symlink or source it from
  your local `.zshrc` if you want one config everywhere.

## Claude Code statusline
- `install.sh` installs a Claude Code statusline (requires `jq`, already in `packages.txt`;
  the step is skipped if `jq` is absent). It copies `claude/statusline.sh` →
  `~/.claude/statusline.sh` (`chmod +x`) and **jq-merges** a `statusLine` key into
  `~/.claude/settings.json` — a merge, not an overwrite, so env-provisioned keys (session
  hooks, telemetry) are preserved.
- `claude/statusline.sh` reads Claude's JSON status payload on stdin and prints:
  `[HH:MM:SS UTC] <dir> (<branch>*+ ⇡N⇣N) · <Model>` — where `*` = unstaged changes,
  `+` = staged, and `⇡N`/`⇣N` = commits ahead/behind upstream. Colors mirror the zsh
  prompt style: dim gray time, cyan dir, magenta branch, blue ahead/behind.

## Claude Code settings (remote envs only)
- Gated on `DOTFILES_REMOTE=1`, so running `install.sh` on a Mac or plain Linux box
  leaves `~/.claude/settings.json` untouched. When enabled, `install.sh` **jq-merges**
  `claude/settings.linux.json` into `~/.claude/settings.json` — scalar keys win, and
  `permissions.allow` is **unioned** so env-provisioned keys (hooks, telemetry) and any
  existing allow entries survive.
- It sets a portable, headless-friendly block: `effortLevel: high`, `fallbackModel: [sonnet]`,
  `autoCompactEnabled`, `useAutoModeDuringPlan`, `skipWorkflowUsageWarning`,
  `remoteControlAtStartup: false`, `theme: light`, `tui: fullscreen`.
- If `WORKSPACE_DIR` is set, a `Read(<WORKSPACE_DIR>/**)` permission is added to the allow list.

## Shell prompt (starship)
- On remote envs (`DOTFILES_REMOTE=1`), `install.sh` copies `starship.toml` →
  `~/.config/starship.toml`, giving a prompt of `directory · git branch · [HH:MM:SS UTC]`
  (UTC pinned via `utc_time_offset`).
- `starship` is installed via `packages.txt` (nix). `zsh.sh` already runs `starship init zsh`;
  `shell.sh` adds `starship init bash` (guarded by `$BASH_VERSION`) so the prompt is present
  in both shells.

## Use it
Clone to `~/.dotfiles` and run the installer (set the env vars first if you want them):
```bash
git clone https://github.com/vipulgowda/dotfiles ~/.dotfiles
DOTFILES_DIR=~/.dotfiles WORKSPACE_DIR=/path/to/workspace DOTFILES_REMOTE=1 \
  bash ~/.dotfiles/install.sh
```
A fresh SSH login then lands you in your workspace with the aliases present.

## Extend it
Add more to `shell.sh` (prompt, exports, functions). Keep it POSIX-ish so it works under
both bash and zsh. Re-running `install.sh` never duplicates lines.

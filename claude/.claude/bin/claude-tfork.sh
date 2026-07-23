#!/usr/bin/env bash
# claude-fork: spawn a forked copy of the current Claude Code session.
#   - inside tmux  -> opens an adjacent pane running `claude --resume <id> --fork-session`
#   - outside tmux -> opens a new terminal window (macOS Terminal/iTerm, or common Linux terminals)
#
# Relies on the SessionStart hook (track-session.sh) having recorded the session ID.
set -euo pipefail

dir="$HOME/.claude/run/sessions"

record=""

# 1. Exact match: same tmux pane we're running in.
if [ -n "${TMUX_PANE:-}" ] && [ -f "$dir/tmux-${TMUX_PANE#%}" ]; then
  record="$dir/tmux-${TMUX_PANE#%}"
fi

# 2. Fallback: per-project latest-session record for this cwd.
if [ -z "$record" ]; then
  proj_key="cwd-$(printf '%s' "$PWD" | shasum -a 1 2>/dev/null | cut -c1-12 || printf '%s' "$PWD" | sha1sum | cut -c1-12)"
  [ -f "$dir/$proj_key" ] && record="$dir/$proj_key"
fi

# 3. Last resort: most recently updated record whose cwd matches, else newest overall.
if [ -z "$record" ] && [ -d "$dir" ]; then
  for f in $(ls -t "$dir" 2>/dev/null); do
    if [ "$(jq -r '.cwd // empty' "$dir/$f" 2>/dev/null)" = "$PWD" ]; then
      record="$dir/$f"; break
    fi
  done
  [ -z "$record" ] && record="$dir/$(ls -t "$dir" | head -n1)"
fi

if [ -z "$record" ] || [ ! -f "$record" ]; then
  echo "FORK FAILED: no tracked session found in $dir — is the SessionStart hook installed?" >&2
  exit 1
fi

sid=$(jq -r '.session_id' "$record")
cwd=$(jq -r '.cwd' "$record")
[ -d "$cwd" ] || cwd="$PWD"

fork_cmd="claude --resume $sid --fork-session"

if [ -n "${TMUX:-}" ]; then
  # New pane to the right, in the session's project dir (resume lookup is cwd-scoped).
  # send-keys (rather than passing the command to split-window) means the fork runs
  # in your normal login shell with your full environment, and the pane survives exit.
  pane_id=$(tmux split-window -h -c "$cwd" -P -F '#{pane_id}')
  tmux send-keys -t "$pane_id" "$fork_cmd" C-m
  echo "FORK OK: session $sid forked into tmux pane $pane_id (dir: $cwd)"
  exit 0
fi

# Not inside tmux: open a new terminal window.
sh_cmd="cd $(printf '%q' "$cwd") && $fork_cmd"

case "$(uname -s)" in
  Darwin)
    if [ -d "/Applications/iTerm.app" ] && pgrep -qx iTerm2 2>/dev/null; then
      osascript -e "tell application \"iTerm\"
        create window with default profile
        tell current session of current window to write text \"$sh_cmd\"
      end tell" >/dev/null
      echo "FORK OK: session $sid forked into a new iTerm window (dir: $cwd)"
    else
      osascript -e "tell application \"Terminal\" to do script \"$sh_cmd\"" >/dev/null
      osascript -e 'tell application "Terminal" to activate' >/dev/null
      echo "FORK OK: session $sid forked into a new Terminal window (dir: $cwd)"
    fi
    exit 0
    ;;
  Linux)
    for term in "${TERMINAL:-}" x-terminal-emulator kitty alacritty gnome-terminal konsole wezterm xterm; do
      [ -n "$term" ] || continue
      if command -v "$term" >/dev/null 2>&1; then
        case "$term" in
          gnome-terminal)
            setsid "$term" -- bash -lc "$sh_cmd; exec bash" >/dev/null 2>&1 & ;;
          konsole)
            setsid "$term" -e bash -lc "$sh_cmd; exec bash" >/dev/null 2>&1 & ;;
          *)
            setsid "$term" -e bash -lc "$sh_cmd; exec bash" >/dev/null 2>&1 & ;;
        esac
        echo "FORK OK: session $sid forked into a new $term window (dir: $cwd)"
        exit 0
      fi
    done
    echo "FORK FAILED: no terminal emulator found. Run manually: $fork_cmd (from $cwd)" >&2
    exit 1
    ;;
  *)
    echo "FORK FAILED: unsupported OS. Run manually: $fork_cmd (from $cwd)" >&2
    exit 1
    ;;
esac

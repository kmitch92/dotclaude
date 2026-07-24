#!/usr/bin/env bash
# claude-trestart: restart the CURRENT Claude Code session IN PLACE — continue it, do NOT fork.
#   - inside tmux  -> respawn the current pane running `claude --resume <id>` (same session, same pane)
#   - outside tmux -> open a new terminal window resuming the session, then terminate the original
#                     claude process so the session relocates cleanly to the new window.
#
# Reuses claude-tfork.sh's session resolution verbatim. Never forks (no --fork-session).
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
  # ls -t gives newest-first by mtime, which is exactly the resolution order we want.
  # shellcheck disable=SC2045
  for f in $(ls -t "$dir" 2>/dev/null); do
    if [ "$(jq -r '.cwd // empty' "$dir/$f" 2>/dev/null)" = "$PWD" ]; then
      record="$dir/$f"; break
    fi
  done
  # shellcheck disable=SC2012
  [ -z "$record" ] && record="$dir/$(ls -t "$dir" | head -n1)"
fi

if [ -z "$record" ] || [ ! -f "$record" ]; then
  echo "RESTART FAILED: no tracked session found in $dir — is the SessionStart hook installed?" >&2
  exit 1
fi

sid=$(jq -r '.session_id' "$record")
cwd=$(jq -r '.cwd' "$record")
[ -d "$cwd" ] || cwd="$PWD"

# Continue the same session — NO --fork-session.
resume_cmd="claude --resume $sid"

# Run a shell snippet fully detached so it outlives this script (and, in the tmux case,
# the pane we are about to respawn). Prefer setsid (Linux); otherwise a disowned subshell.
# Output goes to /dev/null — the actions we schedule report through their own channels.
schedule_detached() {
  local snippet="$1"
  if command -v setsid >/dev/null 2>&1; then
    setsid bash -c "$snippet" >/dev/null 2>&1 &
  else
    ( bash -c "$snippet" >/dev/null 2>&1 ) &
  fi
  disown 2>/dev/null || true
}

if [ -n "${TMUX:-}" ]; then
  pane="${TMUX_PANE:-}"
  [ -n "$pane" ] || pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)"
  # Respawn the SAME pane in place, continuing the session. Scheduled detached with a
  # brief delay so this script prints success and exits 0 BEFORE the pane is killed —
  # that detach is what makes an in-place restart safe.
  schedule_detached "$(printf 'sleep 0.3; tmux respawn-pane -k -t %q -c %q %q' "$pane" "$cwd" "$resume_cmd")"
  echo "RESTART OK: restarting session $sid in place (tmux pane $pane, dir: $cwd)"
  exit 0
fi

# Not inside tmux: open a new terminal window resuming the session, then terminate the
# original claude process ($PPID) after a short delay so the new window is up first.
sh_cmd="cd $(printf '%q' "$cwd") && $resume_cmd"
parent_pid="$PPID"

launched=""
case "$(uname -s)" in
  Darwin)
    if [ -d "/Applications/iTerm.app" ] && pgrep -qx iTerm2 2>/dev/null; then
      osascript -e "tell application \"iTerm\"
        create window with default profile
        tell current session of current window to write text \"$sh_cmd\"
      end tell" >/dev/null
      launched="a new iTerm window"
    else
      osascript -e "tell application \"Terminal\" to do script \"$sh_cmd\"" >/dev/null
      osascript -e 'tell application "Terminal" to activate' >/dev/null
      launched="a new Terminal window"
    fi
    ;;
  Linux)
    for term in "${TERMINAL:-}" x-terminal-emulator kitty alacritty gnome-terminal konsole wezterm xterm; do
      [ -n "$term" ] || continue
      if command -v "$term" >/dev/null 2>&1; then
        setsid "$term" -e bash -lc "$sh_cmd; exec bash" >/dev/null 2>&1 &
        launched="a new $term window"
        break
      fi
    done
    ;;
esac

if [ -z "$launched" ]; then
  echo "RESTART FAILED: no terminal emulator found (or unsupported OS). Run manually: $resume_cmd (from $cwd)" >&2
  exit 1
fi

# Terminate the ORIGINAL claude process, detached and delayed, so we never signal
# synchronously and the new window has time to come up first.
schedule_detached "$(printf 'sleep 0.5; kill %q' "$parent_pid")"
echo "RESTART OK: session $sid relocated to $launched (dir: $cwd); original session terminated."
exit 0

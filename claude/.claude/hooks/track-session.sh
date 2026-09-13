#!/usr/bin/env bash
# SessionStart hook: records this session's ID + cwd so /fork can find it later.
# Claude Code pipes hook input as JSON on stdin, including session_id and cwd.
# Keyed by tmux pane when inside tmux, otherwise by the claude process's tty.
set -euo pipefail

input=$(cat)

session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$session_id" ] || exit 0
[ -n "$cwd" ] || cwd=$(pwd)

dir="$HOME/.claude/run/sessions"
mkdir -p "$dir"

if [ -n "${TMUX_PANE:-}" ]; then
  key="tmux-${TMUX_PANE#%}"
else
  # Hook runs as a child of the claude process, so PPID's tty is the terminal.
  tty_name=$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ' | tr '/' '-' || true)
  key="tty-${tty_name:-unknown}"
fi

# Co-tenancy fields: current git branch (best-effort; empty outside a repo) and
# the raw tmux pane id. git must never abort the hook, hence `|| true`.
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
pane="${TMUX_PANE:-}"

jq -n --arg sid "$session_id" --arg cwd "$cwd" --arg branch "$branch" --arg pane "$pane" \
  '{session_id: $sid, cwd: $cwd, branch: $branch, pane: $pane, updated: now | todate}' > "$dir/$key"

# Also keep a per-project "latest" record as a fallback lookup.
proj_key="cwd-$(printf '%s' "$cwd" | shasum -a 1 2>/dev/null | cut -c1-12 || printf '%s' "$cwd" | sha1sum | cut -c1-12)"
jq -n --arg sid "$session_id" --arg cwd "$cwd" --arg branch "$branch" --arg pane "$pane" \
  '{session_id: $sid, cwd: $cwd, branch: $branch, pane: $pane, updated: now | todate}' > "$dir/$proj_key"

exit 0

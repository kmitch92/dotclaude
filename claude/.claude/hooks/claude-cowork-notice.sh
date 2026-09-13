#!/usr/bin/env bash
# UserPromptSubmit hook: warns when other Claude Code sessions are co-tenant in
# the same cwd AND on the same git branch (risk of conflicting edits).
#
# Claude Code pipes hook input as JSON on stdin ({session_id, cwd}) and treats
# UserPromptSubmit stdout as additionalContext. We:
#   1. Self-refresh THIS session's record (session records are written by the
#      SessionStart hook track-session.sh; refresh keeps branch/pane/updated live).
#   2. Prune stale tmux pane records (pane no longer in `tmux list-panes`).
#   3. Count live co-tenants (other session_id, same cwd + branch).
#   4. Emit a co-tenancy warning as additionalContext when count >= 1.
#
# Contract: best-effort, never blocks the prompt. Any stdout is valid JSON.
# Malformed record files are skipped, not fatal. Always exit 0.
set -euo pipefail

# TTL (seconds) after which a tty-keyed record is considered dead (12h).
readonly TTL=43200

input=$(cat)

session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -n "$session_id" ] || exit 0
[ -n "$cwd" ] || cwd=$(pwd)

dir="$HOME/.claude/run/sessions"
mkdir -p "$dir"

# --- session key (must match track-session.sh) --------------------------------
if [ -n "${TMUX_PANE:-}" ]; then
  key="tmux-${TMUX_PANE#%}"
else
  tty_name=$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ' | tr '/' '-' || true)
  key="tty-${tty_name:-unknown}"
fi

# Live git branch for this session (best-effort; empty outside a repo).
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
pane="${TMUX_PANE:-}"

# --- 1. self-refresh ----------------------------------------------------------
jq -n --arg sid "$session_id" --arg cwd "$cwd" --arg branch "$branch" --arg pane "$pane" \
  '{session_id: $sid, cwd: $cwd, branch: $branch, pane: $pane, updated: now | todate}' \
  > "$dir/$key"

# --- tmux liveness snapshot ---------------------------------------------------
in_tmux=false
live_panes=""
if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
  in_tmux=true
  live_panes=$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null || true)
fi

pane_is_live() {
  # $1 = pane id (e.g. %50). True when it appears in the live-pane snapshot.
  printf '%s\n' "$live_panes" | grep -qxF -- "$1"
}

# --- 2. prune dead tmux pane records ------------------------------------------
# Uses the filename-derived pane id so malformed record bodies never crash us.
# Only tmux-* records are pruned by this rule; tty-* records are left alone.
# An empty live_panes snapshot while in tmux is untrustworthy (our own pane
# must always appear), so skip pruning that run rather than deleting records.
if [ "$in_tmux" = true ] && [ -n "$live_panes" ]; then
  for f in "$dir"/tmux-*; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    if ! pane_is_live "%${b#tmux-}"; then
      rm -f "$f"
    fi
  done
fi

# --- 3. count live co-tenants -------------------------------------------------
count=0
panes_list=""
for f in "$dir"/*; do
  [ -e "$f" ] || continue
  [ "$f" = "$dir/$key" ] && continue
  # Skip malformed record files (guard every downstream jq read).
  jq -e . "$f" >/dev/null 2>&1 || continue

  r_sid=$(jq -r '.session_id // empty' "$f" 2>/dev/null || true)
  r_cwd=$(jq -r '.cwd // empty' "$f" 2>/dev/null || true)
  r_branch=$(jq -r '.branch // empty' "$f" 2>/dev/null || true)
  r_pane=$(jq -r '.pane // empty' "$f" 2>/dev/null || true)

  [ -n "$r_sid" ] || continue
  [ "$r_sid" = "$session_id" ] && continue     # never count my own session
  [ "$r_cwd" = "$cwd" ] || continue            # same working directory
  [ "$r_branch" = "$branch" ] || continue      # same git branch

  b=$(basename "$f")
  cp=""
  case "$b" in
    tmux-*)
      [ "$in_tmux" = true ] || continue        # can't confirm liveness -> skip
      pid="%${b#tmux-}"
      pane_is_live "$pid" || continue
      cp="${r_pane:-$pid}"
      ;;
    tty-*)
      r_updated=$(jq -r '.updated // empty' "$f" 2>/dev/null || true)
      [ -n "$r_updated" ] || continue
      rec_epoch=$(date -u -d "$r_updated" +%s 2>/dev/null \
        || date -u -jf '%Y-%m-%dT%H:%M:%SZ' "$r_updated" +%s 2>/dev/null \
        || echo 0)
      [ "$rec_epoch" -gt 0 ] || continue
      [ "$(( $(date -u +%s) - rec_epoch ))" -le "$TTL" ] || continue
      cp="$r_pane"
      ;;
    *)
      continue                                 # cwd-* fallback etc. never counts
      ;;
  esac

  count=$((count + 1))
  [ -n "$cp" ] && panes_list="${panes_list:+$panes_list }$cp"
done

# --- 4. emit warning (only when at least one live co-tenant) ------------------
if [ "$count" -ge 1 ]; then
  ctx="Co-tenancy notice: ${count} other live Claude Code session(s) share this working directory (${cwd}) on the same branch (${branch:-<none>}). Co-tenant pane(s): ${panes_list:-unknown}. Coordinate edits to avoid clobbering each other's changes."
  jq -n --arg ctx "$ctx" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
fi

exit 0

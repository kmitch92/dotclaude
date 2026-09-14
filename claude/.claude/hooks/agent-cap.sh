#!/usr/bin/env bash
# PreToolUse[Agent] + SubagentStop + SessionStart hook: caps how many `worker`
# and `scout` subagents one session runs at once. Dispatches on hook_event_name.
#   Caps: $HOME/.claude/machine.json {"workerCap":N,"scoutCap":M}; defaults 2/6.
#   PreToolUse below cap: count +1, exit 0, additionalContext "worker N/M, scout N/M".
#   PreToolUse at cap: exit 2, stderr "<type> cap reached (N/M)", count unchanged.
#   SubagentStop: count -1 (floor 0). SessionStart: reset that session's counts.
# Counts live in $HOME/.claude/run/agent-caps/<session>.<type>, guarded by a
# noclobber (O_EXCL) lockfile: flock is not on macOS, and uutils coreutils mkdir
# is not exclusive under simultaneous calls. No `set -e`: on its own failure the
# hook must exit 0 (never block), not die with 1.
set -uo pipefail

input=$(cat) || exit 0
parsed=$(printf '%s' "$input" | jq -r '
  [.hook_event_name, .session_id, .tool_name, (.tool_input.subagent_type? // .agent_type)]
  | map(. // "" | tostring) | join("\u001f")' 2>/dev/null) || exit 0
IFS=$'\037' read -r event sid tool type <<< "$parsed" || true
[ -n "${sid:-}" ] || exit 0

dir="$HOME/.claude/run/agent-caps"
key=$(printf '%s' "$sid" | tr -c 'A-Za-z0-9._-' '_')
lock="$dir/$key.lock"
mkdir -p "$dir" 2>/dev/null || exit 0

acquire_lock() {
  local tries=0 pid
  # noclobber makes bash itself create the lockfile with O_EXCL (atomic).
  until ( set -C; printf '%s\n' "$$" > "$lock" ) 2>/dev/null; do
    tries=$((tries + 1))
    [ "$tries" -le 200 ] || return 1
    pid=$(cat "$lock" 2>/dev/null || true)
    # Stale: holder PID is dead yet still recorded (re-read after kill -0, so a lock
    # released and re-taken meanwhile is not mistaken for stale), or no PID was
    # ever written and the lock is over a minute old.
    if { [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null &&
         [ "$(cat "$lock" 2>/dev/null || true)" = "$pid" ]; } ||
       { [ -z "$pid" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin +1 2>/dev/null)" ]; }; then
      # mv is atomic, so only one contender removes a given stale lock.
      mv "$lock" "$lock.stale.$$" 2>/dev/null && rm -f "$lock.stale.$$"
      continue
    fi
    sleep 0.05
  done
  trap 'rm -f "$lock"' EXIT
}

read_count() {
  local n
  n=$(cat "$dir/$key.$1" 2>/dev/null || true)
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  printf '%s' "$n"
}

valid_int() { case "$1" in ''|*[!0-9]*) return 1 ;; esac; }

case "$event" in
  SessionStart)
    acquire_lock || exit 0
    rm -f "$dir/$key.worker" "$dir/$key.scout"
    ;;
  SubagentStop)
    case "$type" in worker|scout) ;; *) exit 0 ;; esac
    acquire_lock || exit 0
    n=$(read_count "$type")
    [ "$n" -gt 0 ] && n=$((n - 1))
    printf '%s\n' "$n" > "$dir/$key.$type"
    ;;
  PreToolUse)
    [ "$tool" = "Agent" ] || exit 0
    case "$type" in worker|scout) ;; *) exit 0 ;; esac
    caps=$(jq -r '"\(.workerCap // 2) \(.scoutCap // 6)"' "$HOME/.claude/machine.json" 2>/dev/null || true)
    worker_cap=${caps%% *}; scout_cap=${caps##* }
    valid_int "$worker_cap" || worker_cap=2
    valid_int "$scout_cap" || scout_cap=6

    acquire_lock || exit 0
    workers=$(read_count worker)
    scouts=$(read_count scout)
    if [ "$type" = "worker" ]; then cur=$workers; cap=$worker_cap; else cur=$scouts; cap=$scout_cap; fi
    if [ "$cur" -ge "$cap" ]; then
      echo "$type cap reached ($cur/$cap): wait for a running $type to finish before launching another" >&2
      exit 2
    fi
    printf '%s\n' "$((cur + 1))" > "$dir/$key.$type"
    if [ "$type" = "worker" ]; then workers=$((cur + 1)); else scouts=$((cur + 1)); fi
    jq -cn --arg ctx "worker $workers/$worker_cap, scout $scouts/$scout_cap" \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
    ;;
esac

exit 0

#!/usr/bin/env bash
# Stop hook (scope "main"): lints the assistant's last message with the STE
# linter (Simplified Technical English checker) and can block the Stop event
# by printing {"decision":"block","reason":...} when the linter reports a
# hard violation (exit code 2).
#
# One-retry property: Claude Code sets stop_hook_active=true on the retry
# after a block, so this hook never blocks twice in a row for the same
# Stop — a blocked turn always gets exactly one more chance to finish
# un-gated.
#
# STE_GATE=warn disables blocking entirely (linter output is still logged
# and recorded in state, but the Stop is never blocked) — use this to roll
# out or debug the linter without enforcing it.
#
# Env overrides:
#   STE_LINT_BIN   path to the linter executable (default: claude-ste-lint.py
#                  next to this script)
#   STE_STATE_DIR  where per-session/per-agent result JSON is written
#                  (default: $HOME/.claude/ste/state)
#   STE_LOG        JSONL log for gate-level errors (default:
#                  $HOME/.claude/ste/lint.log.jsonl)
#   STE_GATE       set to "warn" to disable blocking
#   STE_SCOPE      "main" (default) or "sub" — set by
#                  claude-ste-subagent-gate.sh, which execs this script to
#                  share logic; selects session_id vs agent_id as the id
#                  and is passed through as --scope to the linter
#
# Contract: reads hook JSON from stdin (session_id, agent_id,
# stop_hook_active, last_assistant_message). Pipes last_assistant_message to
# the linter as:
#   STE_LINT_BIN --text - --scope <scope> --format model --log --session <id>
# Linter exit code: 0 clean, 1 warn, 2 block. Writes
# STE_STATE_DIR/<id>.json with {rc, gated, output, ts, scope}. Prints the
# block decision to stdout iff rc==2 and stop_hook_active!=true and
# STE_GATE!=warn; otherwise prints nothing. If the linter is missing, not
# executable, or exits with an unexpected code, nothing is blocked, nothing
# is printed, and one error line is appended to STE_LOG. Invalid/empty
# stdin or a missing last_assistant_message: exit 0, nothing on stdout.
# Always exits 0.

set -uo pipefail

SCOPE="${STE_SCOPE:-main}"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STE_LINT_BIN="${STE_LINT_BIN:-$SELF_DIR/claude-ste-lint.py}"
STE_STATE_DIR="${STE_STATE_DIR:-$HOME/.claude/ste/state}"
STE_LOG="${STE_LOG:-$HOME/.claude/ste/lint.log.jsonl}"
STE_GATE="${STE_GATE:-}"

log_error() {
  local session="$1" error="$2" ts
  mkdir -p "$(dirname "$STE_LOG")" 2>/dev/null
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq -cn --arg ts "$ts" --arg session "$session" --arg error "$error" \
    '{ts: $ts, event: "gate-error", session: $session, error: $error}' >> "$STE_LOG" 2>/dev/null
  exit 0
}

input="$(cat)"
[ -z "$input" ] && exit 0

if ! printf '%s' "$input" | jq -e . >/dev/null 2>&1; then
  exit 0
fi

msg_type="$(printf '%s' "$input" | jq -r '.last_assistant_message | type' 2>/dev/null || echo "null")"
if [ "$msg_type" != "string" ]; then
  exit 0
fi

last_assistant_message="$(printf '%s' "$input" | jq -r '.last_assistant_message')"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty')"
agent_id="$(printf '%s' "$input" | jq -r '.agent_id // empty')"
stop_hook_active="$(printf '%s' "$input" | jq -r '.stop_hook_active // false')"

if [ "$SCOPE" = "sub" ]; then
  id="$agent_id"
else
  id="$session_id"
fi

if [ ! -x "$STE_LINT_BIN" ]; then
  log_error "$id" "linter not found or not executable: $STE_LINT_BIN"
fi

out="$(printf '%s' "$last_assistant_message" | "$STE_LINT_BIN" --text - --scope "$SCOPE" --format model --log --session "$id")"
rc=$?

case "$rc" in
  0|1|2) ;;
  *) log_error "$id" "linter exited with unexpected code $rc" ;;
esac

gated=false
if [ "$rc" = "2" ] && [ "$stop_hook_active" != "true" ] && [ "$STE_GATE" != "warn" ]; then
  gated=true
fi

mkdir -p "$STE_STATE_DIR" 2>/dev/null
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
jq -cn --arg out "$out" --arg ts "$ts" --arg scope "$SCOPE" --argjson rc "$rc" --argjson gated "$gated" \
  '{rc: $rc, gated: $gated, output: $out, ts: $ts, scope: $scope}' > "$STE_STATE_DIR/$id.json" 2>/dev/null

if [ "$gated" = "true" ]; then
  jq -cn --arg r "$out" '{decision: "block", reason: $r}'
fi

exit 0

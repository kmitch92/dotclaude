#!/usr/bin/env bash
# Stop hook (scope "main"): lints the assistant's last message with the STE
# linter (Simplified Technical English checker) and records the result.
#
# The gate only measures and records; it never refuses the Stop event. A
# forced rewrite costs a second full reply, so the gate does not block.
# It writes the linter's rc and output to a state file for the next
# prompt's reminder hook to read.
#
# Env overrides:
#   STE_LINT_BIN   path to the linter executable (default: claude-ste-lint.py
#                  next to this script)
#   STE_STATE_DIR  where per-session/per-agent result JSON is written
#                  (default: $HOME/.claude/ste/state)
#   STE_LOG        JSONL log for gate-level errors (default:
#                  $HOME/.claude/ste/lint.log.jsonl)
#   STE_SCOPE      "main" (default) or "sub" — set by
#                  claude-ste-subagent-gate.sh, which execs this script to
#                  share logic; selects session_id vs agent_id as the id
#                  and is passed through as --scope to the linter
#
# Contract: reads hook JSON from stdin (session_id, agent_id,
# last_assistant_message). Pipes last_assistant_message to the linter as:
#   STE_LINT_BIN --text - --scope <scope> --format model --log --session <id>
# Linter exit code: 0 clean, 1 warn, 3 linter failure. Writes
# STE_STATE_DIR/<id>.json with {rc, output, ts, scope}. Never prints
# anything to stdout. If the linter is missing, not executable, or exits
# with an unexpected code, one error line is appended to STE_LOG and no
# state file is written. Invalid/empty stdin or a missing
# last_assistant_message: exit 0, nothing on stdout. Always exits 0.

set -uo pipefail

SCOPE="${STE_SCOPE:-main}"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STE_LINT_BIN="${STE_LINT_BIN:-$SELF_DIR/claude-ste-lint.py}"
STE_STATE_DIR="${STE_STATE_DIR:-$HOME/.claude/ste/state}"
STE_LOG="${STE_LOG:-$HOME/.claude/ste/lint.log.jsonl}"

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
  0|1|3) ;;
  *) log_error "$id" "linter exited with unexpected code $rc" ;;
esac

mkdir -p "$STE_STATE_DIR" 2>/dev/null
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
jq -cn --arg out "$out" --arg ts "$ts" --arg scope "$SCOPE" --argjson rc "$rc" \
  '{rc: $rc, output: $out, ts: $ts, scope: $scope}' > "$STE_STATE_DIR/$id.json" 2>/dev/null

exit 0

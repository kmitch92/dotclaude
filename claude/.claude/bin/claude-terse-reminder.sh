#!/usr/bin/env bash
# UserPromptSubmit hook: re-injects the terse-style reminder into context on every
# user prompt, to counter style-drift over long sessions.
#
# The static reminder (STATIC_REMINDER) is always included. Two more parts are
# appended:
#   1. a previous-reply report from the STE linter (claude-ste-lint.py), read
#      from the state file the Stop hook (claude-ste-gate.sh) writes for this
#      session (STE_STATE_DIR/<session_id>.json), via `LINTER --state <file>
#      --format model`. If that state file does not exist, falls back to
#      linting the transcript directly via `LINTER --transcript <path>
#      --last-assistant --format model --scope main`. If the linter is
#      missing, not executable, or exits with a code other than 0/1/2, this
#      part is empty — no error text ever reaches stdout.
#   2. an STE reminder built from rules.tsv: one "ID: fix" line per
#      block-class row, in file order, under the heading "STE block-class
#      checks:".
#
# Claude Code treats UserPromptSubmit as one of the few events whose stdout is added
# to context. We emit the documented JSON `additionalContext` form so the reminder is
# wrapped in a system reminder and inserted alongside the submitted prompt.
#
# Env overrides:
#   STE_LINT_BIN   path to the linter executable (default: claude-ste-lint.py
#                  next to this script)
#   STE_STATE_DIR  where per-session result JSON lives (default:
#                  $HOME/.claude/ste/state)
#   STE_RULES      path to the rules.tsv driving the block-class reminder
#                  (default: ../ste/rules.tsv next to this script)
#
# Contract: always exit 0 (never block/error the prompt). Always outputs
# valid JSON, even on empty/invalid stdin.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STE_LINT_BIN="${STE_LINT_BIN:-$SELF_DIR/claude-ste-lint.py}"
STE_STATE_DIR="${STE_STATE_DIR:-$HOME/.claude/ste/state}"
STE_RULES="${STE_RULES:-$SELF_DIR/../ste/rules.tsv}"

STATIC_REMINDER="Style reminder: full rules in ~/.claude/output-styles/terse.md. One point per response, no essays. Stay on the current task; anything else is one \"Also:\" line. Plain technical words, nothing stylised. No claim without evidence. No praise, no apology. Prefer diagrams. Absolute paths. Worrying that a reply is running long is itself the signal to stop and ask what you are actually trying to say, and what the task in front of you is. Finding the signal in your own noise is your job, not the developer's."

emit() {
  jq -cn --arg ctx "$1" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
}

hook_json=$(cat 2>/dev/null || echo "")

session_id=""
transcript_path=""
if [ -n "$hook_json" ] && printf '%s' "$hook_json" | jq -e . >/dev/null 2>&1; then
  session_id=$(printf '%s' "$hook_json" | jq -r '.session_id // empty' 2>/dev/null || echo "")
  transcript_path=$(printf '%s' "$hook_json" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")
fi

# Part 2: previous-reply report from the linter.
part2=""
out=""
rc=-1
state_file="$STE_STATE_DIR/$session_id.json"
if [ -f "$state_file" ] && [ -x "$STE_LINT_BIN" ]; then
  out=$("$STE_LINT_BIN" --state "$state_file" --format model 2>/dev/null)
  rc=$?
elif [ -n "$transcript_path" ] && [ -f "$transcript_path" ] && [ -x "$STE_LINT_BIN" ]; then
  out=$("$STE_LINT_BIN" --transcript "$transcript_path" --last-assistant --format model --scope main 2>/dev/null)
  rc=$?
fi

case "$rc" in
  0|1|2) part2="$out" ;;
  *) part2="" ;;
esac

# Part 3: STE reminder built from rules.tsv (block-class rows only).
part3="STE block-class checks:"
if [ -f "$STE_RULES" ]; then
  rules_lines=$(
    awk -F'\t' 'NR==1 { next } /^#/ { next } $3 == "block" { print $1 ": " $6 }' "$STE_RULES" 2>/dev/null
  )
  if [ -n "$rules_lines" ]; then
    part3="${part3}"$'\n'"${rules_lines}"
  fi
fi

additional_context="$STATIC_REMINDER"$'\n'
if [ -n "$part2" ]; then
  additional_context="${additional_context}${part2}"$'\n'
fi
additional_context="${additional_context}${part3}"

emit "$additional_context"
exit 0

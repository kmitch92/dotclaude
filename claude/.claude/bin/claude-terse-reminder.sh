#!/usr/bin/env bash
# UserPromptSubmit hook: re-injects the terse-style reminder into context on every
# user prompt, to counter style-drift over long sessions.
#
# The static reminder (STATIC_REMINDER) is always included, as one line. A second
# part summarises the previous reply's STE (Simplified Technical English) lint
# result:
#   1. a previous-reply report from the STE linter (claude-ste-lint.py), read
#      from the state file the Stop hook (claude-ste-gate.sh) writes for this
#      session (STE_STATE_DIR/<session_id>.json), via `LINTER --state <file>
#      --format model`. If that state file does not exist, falls back to
#      linting the transcript directly via `LINTER --transcript <path>
#      --last-assistant --format model --scope main`. If the linter is
#      missing, not executable, or exits with a code other than 0/1, this
#      part is empty — no error text ever reaches stdout.
#   2. that report (one line per hit) is then collapsed: hits are counted per
#      rule id (matched against rules.tsv), sorted by count descending, and
#      only the top 3 ids are printed, one line each, as
#      "<ID> x<count>: <fix from rules.tsv>". A clean previous reply (no ids
#      found) adds nothing.
#
# The whole additionalContext text is capped at 6 lines (via `head -n 6`) as a
# hard guard, regardless of how much the linter or rules.tsv would otherwise add.
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
#   STE_RULES      path to the rules.tsv used to look up the fix text for
#                  each rule id (default: ../ste/rules.tsv next to this script)
#
# Contract: always exit 0 (never halt or error the prompt). Always outputs
# valid JSON, even on empty/invalid stdin.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STE_LINT_BIN="${STE_LINT_BIN:-$SELF_DIR/claude-ste-lint.py}"
STE_STATE_DIR="${STE_STATE_DIR:-$HOME/.claude/ste/state}"
STE_RULES="${STE_RULES:-$SELF_DIR/../ste/rules.tsv}"

STATIC_REMINDER="Style reminder: ~/.claude/output-styles/terse.md. One point per reply. Lead with the outcome. Evidence for every claim."

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

# Part 1: previous-reply report from the linter.
part1=""
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

# Code 3 is a linter failure, not a verdict, so it falls through to the
# empty branch along with any other unexpected code.
case "$rc" in
  0|1) part1="$out" ;;
  *) part1="" ;;
esac

# Part 2: collapse part1 into at most 3 "<ID> x<count>: <fix>" lines, highest
# count first. A rule id is counted once per line of part1 it appears in.
part2=""
if [ -n "$part1" ] && [ -f "$STE_RULES" ]; then
  counts_tmp="$(mktemp)"
  while IFS=$'\t' read -r id _ _ _ _ fix; do
    case "$id" in
      id|'#'*|'') continue ;;
    esac
    hit_count=$(printf '%s\n' "$part1" | grep -cE "\\b${id}\\b" 2>/dev/null)
    hit_count=${hit_count:-0}
    if [ "$hit_count" -gt 0 ]; then
      printf '%s\t%s\t%s\n' "$hit_count" "$id" "$fix" >> "$counts_tmp"
    fi
  done < "$STE_RULES"
  if [ -s "$counts_tmp" ]; then
    part2=$(sort -t "$(printf '\t')" -k1,1nr "$counts_tmp" | head -n 3 | awk -F'\t' '{printf "%s x%s: %s\n", $2, $1, $3}')
  fi
  rm -f "$counts_tmp"
fi

additional_context="$STATIC_REMINDER"
if [ -n "$part2" ]; then
  additional_context="${additional_context}"$'\n'"${part2}"
fi

additional_context="$(printf '%s' "$additional_context" | head -n 6)"

emit "$additional_context"
exit 0

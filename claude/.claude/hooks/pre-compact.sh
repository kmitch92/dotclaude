#!/usr/bin/env bash
# PreCompact hook: reads one JSON object on stdin (session_id, transcript_path,
#   cwd, hook_event_name "PreCompact", trigger "auto"|"manual",
#   custom_instructions). Runs the sibling script compact-timeline.sh
#   (resolved relative to this script's own path, never PATH) with
#   transcript_path as its single argument, and on success writes that
#   script's stdout to $HOME/.claude/run/compact/<session_id>.md. On any
#   failure (missing session_id/transcript_path, bad stdin, missing or
#   failing compact-timeline.sh) the hook writes no sidecar, notes the cause
#   on stderr, and continues. After writing a sidecar it prunes regular
#   files directly inside the sidecar directory older than
#   COMPACT_SIDECAR_MAX_AGE_DAYS days (default 14, non-recursive; prune
#   failures are swallowed). It always prints a plain-text instruction
#   block to stdout and exits 0; it must never exit 2, never block
#   compaction, and never invoke the claude CLI.
set -uo pipefail

input=$(cat) || exit 0
[ -n "$input" ] || exit 0

parsed=$(printf '%s' "$input" | jq -r '
  [.session_id, .transcript_path] | map(. // "" | tostring) | join("\u001f")' 2>/dev/null) || exit 0
IFS=$'\037' read -r session_id transcript_path <<< "$parsed" || true
[ -n "${session_id:-}" ] || exit 0
[ -n "${transcript_path:-}" ] || exit 0

hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
timeline_script="$hook_dir/compact-timeline.sh"

if [ -x "$timeline_script" ]; then
  tmp_out=$(mktemp "${TMPDIR:-/tmp}/pre-compact-timeline.XXXXXX")
  if "$timeline_script" "$transcript_path" >"$tmp_out" 2>"$tmp_out.err"; then
    dest_dir="$HOME/.claude/run/compact"
    mkdir -p "$dest_dir"
    mv "$tmp_out" "$dest_dir/$session_id.md"
    rm -f "$tmp_out.err"
    max_age_days="${COMPACT_SIDECAR_MAX_AGE_DAYS:-14}"
    case "$max_age_days" in
      ''|*[!0-9]*) max_age_days=14 ;;
    esac
    find "$dest_dir" -maxdepth 1 -type f -mtime +"$max_age_days" -delete >/dev/null 2>&1 || true
  else
    echo "pre-compact.sh: compact-timeline.sh failed: $(cat "$tmp_out.err" 2>/dev/null)" >&2
    rm -f "$tmp_out" "$tmp_out.err"
  fi
else
  echo "pre-compact.sh: compact-timeline.sh not found or not executable at $timeline_script" >&2
fi

cat <<'INSTRUCTIONS'
## Compact Instructions (dotclaude)

A machine-generated action log for this session (every user ask, tool call, file edit, test run and error) will be injected into the new context by a SessionStart hook. Do not reproduce it; reference it.

Add these sections after section 9, numbered the same way:

10. Direction changes: every point where the user redirected, cancelled or corrected the work. Quote the user's words verbatim and state what changed as a result.
11. WIP state: every item started and not finished. For each: what is done, what is not, the absolute file paths involved, and the evidence (test name, command, output line) that it is or is not working. Write "unverified" where nothing was run.
12. Tests and checks run: each command run to verify work, with its result in one line. Write "none" if nothing was run.
13. Open questions: every question raised and not yet answered, including questions the assistant raised that the user did not resolve.

In section 3 list every file path verbatim and absolute; never summarise a group as "several files". In section 6 include every user message verbatim, not paraphrased. In section 9 quote the last user message and the last assistant sentence verbatim.
INSTRUCTIONS

exit 0

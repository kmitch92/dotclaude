#!/usr/bin/env bash
# SessionStart hook (matcher "compact"): reads one JSON object on stdin
#   (session_id, transcript_path, cwd, hook_event_name, source). When source
#   is exactly "compact" and the sidecar $HOME/.claude/run/compact/<session_id>.md
#   (written by pre-compact.sh) exists, prints hookSpecificOutput with
#   additionalContext set to a fixed header line followed by the sidecar
#   content (truncated at 24000 characters with a pointer back to the full
#   file if longer). For any other source, missing/empty session_id, missing
#   or non-JSON stdin, or a missing sidecar, prints nothing. Never modifies
#   or deletes the sidecar, never invokes the claude CLI, never exits 2.
set -uo pipefail

input=$(cat) || exit 0
[ -n "$input" ] || exit 0

parsed=$(printf '%s' "$input" | jq -r '
  [.session_id, .source] | map(. // "" | tostring) | join("\u001f")' 2>/dev/null) || exit 0
IFS=$'\037' read -r session_id source <<< "$parsed" || true
[ -n "${session_id:-}" ] || exit 0
[ "${source:-}" = "compact" ] || exit 0

sidecar="$HOME/.claude/run/compact/$session_id.md"
[ -f "$sidecar" ] || exit 0

content=$(cat "$sidecar"; printf x) || exit 0
content="${content%x}"

header="Machine-generated action log for this session, captured just before compaction. Treat it as authoritative over the summary where they disagree."

if [ "${#content}" -gt 24000 ]; then
  body="${content:0:24000}"$'\n'"[truncated; full log at $sidecar]"
else
  body="$content"
fi

text="$header"$'\n\n'"$body"

jq -cn --arg ctx "$text" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'

exit 0

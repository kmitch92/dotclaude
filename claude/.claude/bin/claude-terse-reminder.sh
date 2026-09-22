#!/usr/bin/env bash
# UserPromptSubmit hook: re-injects the terse-style reminder into context on every
# user prompt, to counter style-drift over long sessions.
#
# Reads hook JSON from stdin with transcript_path. Inspects the last assistant message
# and appends complaint sentences if:
#   - prose word count (excluding code blocks and box-drawing lines) exceeds 120
#   - more than 3 "Also:" lines, or any "Also:" line exceeds 20 words
#
# Claude Code treats UserPromptSubmit as one of the few events whose stdout is added
# to context. We emit the documented JSON `additionalContext` form so the reminder is
# wrapped in a system reminder and inserted alongside the submitted prompt.
#
# Contract: always exit 0 (never block/error the prompt). Reads only the transcript
# tail, fast and deterministic. Always outputs valid JSON.

STATIC_REMINDER="Style reminder: full rules in ~/.claude/output-styles/terse.md. One point per response, no essays. Stay on the current task; anything else is one \"Also:\" line. Plain technical words, nothing stylised. No claim without evidence. No praise, no apology. Prefer diagrams. Absolute paths. Worrying that a reply is running long is itself the signal to stop and ask what you are actually trying to say, and what the task in front of you is. Finding the signal in your own noise is your job, not the developer's."

additional_context="$STATIC_REMINDER"

# Try to read and parse the input JSON
hook_json=$(cat 2>/dev/null || echo "")
if [ -z "$hook_json" ]; then
  # Empty stdin; emit reminder alone
  jq -cn --arg ctx "$additional_context" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
  exit 0
fi

# Parse hook JSON; if it fails, emit reminder alone
transcript_path=$(jq -r '.transcript_path // empty' 2>/dev/null <<< "$hook_json" || echo "")

if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
  # Missing or unreadable transcript; emit reminder alone
  jq -cn --arg ctx "$additional_context" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
  exit 0
fi

# Read the last ~400 lines of the transcript, splitting into records (starting each at lines with { at column 0),
# validating each record as JSON, and skipping unparseable ones to find the last assistant message with text
last_assistant_msg=$(
  tail -n 400 "$transcript_path" 2>/dev/null |
  jq -Rrn '
    reduce (limit(400; inputs)) as $line (
      {records: [], current: ""};
      if $line | startswith("{") then
        if .current != "" then
          .records += [.current]
        else . end |
        .current = $line
      else
        .current += (if .current == "" then $line else "\n" + $line end)
      end
    ) |
    if .current != "" then (.records += [.current]) else . end |
    .records |
    map(try fromjson catch empty) |
    reverse |
    map(select(.type == "assistant") | .message.content | map(select(.type == "text") | .text) | join(" ") | select(. != null and . != "")) |
    .[0] // empty
  ' 2>/dev/null || echo ""
)

if [ -z "$last_assistant_msg" ]; then
  # No valid assistant message found; emit reminder alone
  jq -cn --arg ctx "$additional_context" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
  exit 0
fi

# Process the message to count prose words
# Step 1: Remove fenced code blocks (``` to ```)
prose_text=$(
  printf '%s' "$last_assistant_msg" |
  awk '
    /^```/ { in_code = !in_code; next }
    !in_code { print }
  '
)

# Step 2: Remove lines with box-drawing characters
prose_text=$(
  printf '%s' "$prose_text" |
  grep -v '[│├└─┌┐┘┬┴┼]' || true
)

# Step 3: Count whitespace-separated tokens
word_count=$(printf '%s' "$prose_text" | wc -w)

# Check for violations
violations=""

if [ "$word_count" -gt 120 ]; then
  violations="${violations}You wrote $word_count words; the limit is 120. "
  violations="${violations}One point per response: state it, stop; anything beyond is noise. "
fi

# Count occurrences of "Also:" in the entire message
also_count=$(printf '%s' "$last_assistant_msg" | grep -o 'Also:' | wc -l)

# Check if any line containing "Also:" exceeds 20 words
also_line_violations=false

while IFS= read -r line; do
  if [[ "$line" == *"Also:"* ]]; then
    line_words=$(printf '%s' "$line" | wc -w)
    if [ "$line_words" -gt 20 ]; then
      also_line_violations=true
      break
    fi
  fi
done <<< "$last_assistant_msg"

if [ "$also_count" -gt 3 ] || [ "$also_line_violations" = true ]; then
  violations="${violations}At most three \"Also:\" lines, each one sentence under 20 words, a pointer not an explanation. "
fi

# Append violations to the reminder if any
if [ -n "$violations" ]; then
  additional_context="${STATIC_REMINDER} ${violations}"
fi

# Output valid JSON with jq
jq -cn --arg ctx "$additional_context" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'

exit 0

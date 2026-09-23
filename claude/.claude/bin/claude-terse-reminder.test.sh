#!/usr/bin/env bash
# Behavioral tests for claude-terse-reminder.sh (UserPromptSubmit hook).
#
# Contract: reads hook JSON on stdin with a `.transcript_path` field pointing to
# a JSONL transcript. Measures the most recent assistant message and appends
# complaints to the static style reminder when LENGTH (>120 words, excluding code
# blocks and box-drawing lines) or ALSO-BLOCK (>3 "Also:" lines, or any "Also:"
# line >20 words) rules are broken. Always exits 0 and outputs valid JSON.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$TEST_DIR/claude-terse-reminder.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/claude-terse-reminder-test.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

pass_count=0
fail_count=0

pass() { printf '    ok   - %s\n' "$1"; pass_count=$((pass_count + 1)); }
fail() { printf '    FAIL - %s\n' "$1"; fail_count=$((fail_count + 1)); }

assert_eq() {
  local actual="$1" expected="$2" msg="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$msg"
  else
    fail "$msg (expected [$expected], got [$actual])"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    pass "$msg"
  else
    fail "$msg (expected to contain: [$needle])"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    fail "$msg (expected NOT to contain: [$needle])"
  else
    pass "$msg"
  fi
}

RC=0
OUT=""

run_hook() {
  local input="$1"
  bash "$SCRIPT" <<< "$input" >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
}

run_hook_empty_stdin() {
  bash "$SCRIPT" </dev/null >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
}

# Helper to create a transcript with an assistant message
# $1: message text
# Returns path to created JSONL file
create_transcript_with_assistant() {
  local msg="$1"
  local transcript="$WORK/transcript.jsonl"
  jq -n --arg text "$msg" '{
    type: "assistant",
    message: {
      content: [
        {type: "text", text: $text}
      ]
    }
  }' > "$transcript"
  echo "$transcript"
}

# Helper to create a transcript with multiple entries
# Takes newline-separated JSON lines
create_transcript_from_lines() {
  local transcript="$WORK/transcript.jsonl"
  cat > "$transcript"
  echo "$transcript"
}

# Helper to assert valid JSON output
assert_valid_json() {
  local output="$1" msg="$2"
  if echo "$output" | jq -e . >/dev/null 2>&1; then
    pass "$msg"
  else
    fail "$msg (output is not valid JSON: $output)"
  fi
}

echo "== script is present and executable =="
if [ -x "$SCRIPT" ]; then
  pass "script exists and is executable"
else
  fail "script exists and is executable (missing or not executable: $SCRIPT)"
fi

echo "== test 1: short assistant message (about 20 words) =="
TRANSCRIPT="$(create_transcript_with_assistant "This is a short message about something.")"
run_hook "{\"hook_event_name\":\"UserPromptSubmit\",\"transcript_path\":\"$TRANSCRIPT\",\"prompt\":\"hi\"}"
assert_eq "$RC" "0" "exits 0"
assert_valid_json "$OUT" "output is valid JSON"
assert_contains "$OUT" "Style reminder:" "output contains style reminder"
assert_not_contains "$OUT" "120" "no length complaint"
assert_not_contains "$OUT" "verbose" "no verbosity complaint"

echo "== test 2: long assistant message (250 words of plain prose) =="
LONG_MSG="This is a test message. $(printf 'word '; for i in {1..245}; do printf 'test '; done)"
TRANSCRIPT="$(create_transcript_with_assistant "$LONG_MSG")"
run_hook "{\"hook_event_name\":\"UserPromptSubmit\",\"transcript_path\":\"$TRANSCRIPT\",\"prompt\":\"hi\"}"
assert_eq "$RC" "0" "exits 0"
assert_valid_json "$OUT" "output is valid JSON"
assert_contains "$OUT" "Style reminder:" "output contains style reminder"
assert_contains "$OUT" "120" "flags length with 120"

echo "== test 3: long message with fenced code block (30 words + 300-word block) =="
CODE_MSG="This is a short prose. Some more text here. And a bit more for good measure.
\`\`\`
code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block code block
\`\`\`"
TRANSCRIPT="$(create_transcript_with_assistant "$CODE_MSG")"
run_hook "{\"hook_event_name\":\"UserPromptSubmit\",\"transcript_path\":\"$TRANSCRIPT\",\"prompt\":\"hi\"}"
assert_eq "$RC" "0" "exits 0"
assert_valid_json "$OUT" "output is valid JSON"
assert_contains "$OUT" "Style reminder:" "output contains style reminder"
assert_not_contains "$OUT" "120" "no length complaint (code excluded)"

echo "== test 4: long message with box-drawing diagram (30 words + 200 words of box-drawing) =="
DIAGRAM_MSG="This is a short message here with some prose.
├── item 1
│   ├── subitem a
│   └── subitem b
├── item 2
│   ├── subitem c
│   ├── subitem d
│   └── subitem e
└── item 3
    ├── subitem f
    └── subitem g
More text to add. Some additional prose lines.
┌─────────────┬──────────────┐
│ Header 1    │ Header 2     │
├─────────────┼──────────────┤
│ Data 1      │ Data 2       │
│ Data 3      │ Data 4       │
│ Data 5      │ Data 6       │
└─────────────┴──────────────┘"
TRANSCRIPT="$(create_transcript_with_assistant "$DIAGRAM_MSG")"
run_hook "{\"hook_event_name\":\"UserPromptSubmit\",\"transcript_path\":\"$TRANSCRIPT\",\"prompt\":\"hi\"}"
assert_eq "$RC" "0" "exits 0"
assert_valid_json "$OUT" "output is valid JSON"
assert_contains "$OUT" "Style reminder:" "output contains style reminder"
assert_not_contains "$OUT" "120" "no length complaint (diagrams excluded)"

echo "== test 5: assistant message with four short 'Also:' lines =="
FOUR_ALSO="This is my response. Also: first point. Also: second point. Also: third point. Also: fourth point."
TRANSCRIPT="$(create_transcript_with_assistant "$FOUR_ALSO")"
run_hook "{\"hook_event_name\":\"UserPromptSubmit\",\"transcript_path\":\"$TRANSCRIPT\",\"prompt\":\"hi\"}"
assert_eq "$RC" "0" "exits 0"
assert_valid_json "$OUT" "output is valid JSON"
assert_contains "$OUT" "Style reminder:" "output contains style reminder"
assert_contains "$OUT" "three" "flags Also-block rule mentioning three"

echo "== test 6: assistant message with two 'Also:' lines, one 30 words long =="
LONG_ALSO_MSG="This is my response. Also: this is a short line. Also: this is a much longer line that exceeds the word limit and should trigger the rule."
TRANSCRIPT="$(create_transcript_with_assistant "$LONG_ALSO_MSG")"
run_hook "{\"hook_event_name\":\"UserPromptSubmit\",\"transcript_path\":\"$TRANSCRIPT\",\"prompt\":\"hi\"}"
assert_eq "$RC" "0" "exits 0"
assert_valid_json "$OUT" "output is valid JSON"
assert_contains "$OUT" "Style reminder:" "output contains style reminder"
assert_contains "$OUT" "three" "flags Also-block rule"

echo "== test 7: assistant message with three short 'Also:' lines =="
THREE_ALSO="This is my response. Also: first point. Also: second point. Also: third point."
TRANSCRIPT="$(create_transcript_with_assistant "$THREE_ALSO")"
run_hook "{\"hook_event_name\":\"UserPromptSubmit\",\"transcript_path\":\"$TRANSCRIPT\",\"prompt\":\"hi\"}"
assert_eq "$RC" "0" "exits 0"
assert_valid_json "$OUT" "output is valid JSON"
assert_contains "$OUT" "Style reminder:" "output contains style reminder"
assert_not_contains "$OUT" "three" "no Also-block complaint"

echo "== test 8: transcript with user message at end, long assistant before it =="
TRANSCRIPT="$WORK/transcript_mixed.jsonl"
LONG_TEXT="Message. $(printf 'word '; for i in {1..245}; do printf 'test '; done)"
jq -n --arg text "$LONG_TEXT" '[
  {type: "assistant", message: {content: [{type: "text", text: $text}]}},
  {type: "user", message: {content: [{type: "text", text: "hello"}]}}
][]' > "$TRANSCRIPT"
run_hook "{\"hook_event_name\":\"UserPromptSubmit\",\"transcript_path\":\"$TRANSCRIPT\",\"prompt\":\"hi\"}"
assert_eq "$RC" "0" "exits 0"
assert_valid_json "$OUT" "output is valid JSON"
assert_contains "$OUT" "Style reminder:" "output contains style reminder"
assert_contains "$OUT" "120" "long assistant message is flagged"

echo "== test 9: last assistant has only thinking/tool_use, previous is short =="
TRANSCRIPT="$WORK/transcript_thinking.jsonl"
jq -n '[
  {type: "assistant", message: {content: [{type: "text", text: "Short message."}]}},
  {type: "assistant", message: {content: [{type: "thinking", thinking: "internal thought"}, {type: "tool_use", id: "t1", name: "Read", input: {}}]}}
][]' > "$TRANSCRIPT"
run_hook "{\"hook_event_name\":\"UserPromptSubmit\",\"transcript_path\":\"$TRANSCRIPT\",\"prompt\":\"hi\"}"
assert_eq "$RC" "0" "exits 0"
assert_valid_json "$OUT" "output is valid JSON"
assert_contains "$OUT" "Style reminder:" "output contains style reminder"
assert_not_contains "$OUT" "120" "no length complaint"

echo "== test 10: truncated first line (unparseable JSON), then long valid assistant message =="
TRANSCRIPT="$WORK/transcript_truncated.jsonl"
(
  printf 'sage":{"content":[{"type":"text","text":"cut off"}]}}'
  printf '\n'
  jq -n --arg text "This is a test message. $(printf 'word '; for i in {1..245}; do printf 'test '; done)" '{
    type: "assistant",
    message: {
      content: [
        {type: "text", text: $text}
      ]
    }
  }'
) > "$TRANSCRIPT"
run_hook "{\"hook_event_name\":\"UserPromptSubmit\",\"transcript_path\":\"$TRANSCRIPT\",\"prompt\":\"hi\"}"
assert_eq "$RC" "0" "exits 0"
assert_valid_json "$OUT" "output is valid JSON"
assert_contains "$OUT" "Style reminder:" "output contains style reminder"
assert_contains "$OUT" "120" "long message still flagged despite truncated first line"

echo "== test 11: garbage line in middle of valid entries with multiple Also: lines =="
TRANSCRIPT="$WORK/transcript_garbage.jsonl"
(
  jq -n '{
    type: "assistant",
    message: {
      content: [
        {type: "text", text: "Short message."}
      ]
    }
  }'
  printf '\nnot json at all\n'
  jq -n '{
    type: "assistant",
    message: {
      content: [
        {type: "text", text: "This is my response. Also: first point. Also: second point. Also: third point. Also: fourth point."}
      ]
    }
  }'
) > "$TRANSCRIPT"
run_hook "{\"hook_event_name\":\"UserPromptSubmit\",\"transcript_path\":\"$TRANSCRIPT\",\"prompt\":\"hi\"}"
assert_eq "$RC" "0" "exits 0"
assert_valid_json "$OUT" "output is valid JSON"
assert_contains "$OUT" "Style reminder:" "output contains style reminder"
assert_contains "$OUT" "three" "Also-block rule fires despite garbage line"

echo "== test 12: missing transcript_path key =="
run_hook "{\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":\"hi\"}"
assert_eq "$RC" "0" "exits 0"
assert_valid_json "$OUT" "output is valid JSON"
assert_contains "$OUT" "Style reminder:" "output contains static reminder"
assert_not_contains "$OUT" "120" "no length complaint"

echo "== test 13: transcript_path pointing to nonexistent file =="
run_hook "{\"hook_event_name\":\"UserPromptSubmit\",\"transcript_path\":\"/nonexistent/path/transcript.jsonl\",\"prompt\":\"hi\"}"
assert_eq "$RC" "0" "exits 0"
assert_valid_json "$OUT" "output is valid JSON"
assert_contains "$OUT" "Style reminder:" "output contains static reminder"
assert_not_contains "$OUT" "120" "no length complaint"

echo "== test 14: malformed JSON on stdin =="
run_hook "{\"hook_event_name\":\"UserPromptSubmit\",\"transcript_path\":\"$WORK/file.jsonl\""
assert_eq "$RC" "0" "exits 0"
assert_valid_json "$OUT" "output is valid JSON"
assert_contains "$OUT" "Style reminder:" "output contains static reminder"

echo "== test 15: empty stdin =="
run_hook_empty_stdin
assert_eq "$RC" "0" "exits 0"
assert_valid_json "$OUT" "output is valid JSON"
assert_contains "$OUT" "Style reminder:" "output contains static reminder"

echo "== test 16: all error cases exit with 0 =="
# (Already tested above, just verify one more time)
TRANSCRIPT="$(create_transcript_with_assistant "Short.")"
run_hook "{\"hook_event_name\":\"UserPromptSubmit\",\"transcript_path\":\"$TRANSCRIPT\",\"prompt\":\"hi\"}"
assert_eq "$RC" "0" "normal case exits 0"
run_hook "{\"hook_event_name\":\"UserPromptSubmit\"}"
assert_eq "$RC" "0" "error case exits 0"

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

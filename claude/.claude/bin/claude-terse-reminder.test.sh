#!/usr/bin/env bash
# Behavioral tests for claude-terse-reminder.sh (UserPromptSubmit hook).
#
# Contract: reads hook JSON on stdin ({session_id, transcript_path, cwd,
# hook_event_name}). Emits exactly one JSON object on stdout:
# {"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"<text>"}}.
# additionalContext is three parts joined by newlines:
#   1. the static STATIC_REMINDER sentence block (unchanged, starts "Style
#      reminder: full rules in ~/.claude/output-styles/terse.md.")
#   2. a previous-reply report from STE_LINT_BIN: if STE_STATE_DIR/<session_id>.json
#      exists, its stdout is `LINTER --state <file> --format model`; else if
#      transcript_path exists, `LINTER --transcript <path> --last-assistant
#      --format model --scope main`; on linter missing/not-executable/exit
#      code outside 0/1/2, this part is empty (no error text leaks into context)
#   3. an STE reminder built from rules.tsv (path from STE_RULES): heading
#      "STE block-class checks:" then one "ID: fix" line per block-class row,
#      in file order; warn-class rows are not listed.
# Always exits 0 and prints valid JSON, even on empty/invalid stdin.
#
# Stubbed env: HOME is a throwaway dir. A fake linter at $WORK/fakelint.sh
# records its argv to $WORK/lint.argv and behaves per env FAKE_RC / FAKE_OUT.
# A rules.tsv fixture with 2 block rows and 1 warn row lives at $WORK/rules.tsv.

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
    fail "$msg (expected to contain: [$needle], got [$haystack])"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    fail "$msg (expected NOT to contain: [$needle], got [$haystack])"
  else
    pass "$msg"
  fi
}

assert_starts_with() {
  local haystack="$1" prefix="$2" msg="$3"
  case "$haystack" in
    "$prefix"*) pass "$msg" ;;
    *) fail "$msg (expected to start with: [$prefix], got [$haystack])" ;;
  esac
}

assert_valid_json() {
  local output="$1" msg="$2"
  if echo "$output" | jq -e . >/dev/null 2>&1; then
    pass "$msg"
  else
    fail "$msg (output is not valid JSON: $output)"
  fi
}

HOME_DIR="$(mktemp -d "$WORK/home.XXXXXX")"
CWD="$HOME_DIR/proj"
mkdir -p "$CWD"

STATE_DIR="$WORK/state"
RULES_FILE="$WORK/rules.tsv"
FAKELINT="$WORK/fakelint.sh"
ARGV_FILE="$WORK/lint.argv"

cat > "$FAKELINT" <<FAKE
#!/usr/bin/env bash
printf '%s\n' "\$*" > "$ARGV_FILE"
if [ -n "\${FAKE_OUT:-}" ]; then
  printf '%s' "\$FAKE_OUT"
fi
exit "\${FAKE_RC:-0}"
FAKE
chmod +x "$FAKELINT"

printf 'id\tste_rule\tclass\tscope\tmessage\tfix\n' > "$RULES_FILE"
printf 'FIX-ONE\t1.1\tblock\tall\tMessage one\tFix instruction one.\n' >> "$RULES_FILE"
printf 'WARN-ONE\t9.9\twarn\tall\tWarn message\tWarn fix text.\n' >> "$RULES_FILE"
printf 'FIX-TWO\t2.2\tblock\tmain\tMessage two\tFix instruction two.\n' >> "$RULES_FILE"

SESSION_ID="SID-TERSE-1"

STATIC_REMINDER="Style reminder: full rules in ~/.claude/output-styles/terse.md. One point per response, no essays. Stay on the current task; anything else is one \"Also:\" line. Plain technical words, nothing stylised. No claim without evidence. No praise, no apology. Prefer diagrams. Absolute paths. Worrying that a reply is running long is itself the signal to stop and ask what you are actually trying to say, and what the task in front of you is. Finding the signal in your own noise is your job, not the developer's."

hook_json() {
  local sid="$1" transcript="$2"
  jq -cn --arg sid "$sid" --arg tp "$transcript" --arg cwd "$CWD" '{
    session_id: $sid, transcript_path: $tp, cwd: $cwd, hook_event_name: "UserPromptSubmit"
  }'
}

RC=0
OUT=""
CTX=""

run_hook() {
  local input="$1"
  rm -f "$ARGV_FILE"
  HOME="$HOME_DIR" STE_LINT_BIN="$FAKELINT" STE_STATE_DIR="$STATE_DIR" STE_RULES="$RULES_FILE" \
    bash "$SCRIPT" <<< "$input" >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
  CTX="$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)"
}

run_hook_with_lintbin() {
  local input="$1" lintbin="$2"
  rm -f "$ARGV_FILE"
  HOME="$HOME_DIR" STE_LINT_BIN="$lintbin" STE_STATE_DIR="$STATE_DIR" STE_RULES="$RULES_FILE" \
    bash "$SCRIPT" <<< "$input" >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
  CTX="$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)"
}

run_hook_empty_stdin() {
  rm -f "$ARGV_FILE"
  HOME="$HOME_DIR" STE_LINT_BIN="$FAKELINT" STE_STATE_DIR="$STATE_DIR" STE_RULES="$RULES_FILE" \
    bash "$SCRIPT" </dev/null >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
  CTX="$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)"
}

echo "== script is present and executable =="
if [ -x "$SCRIPT" ]; then
  pass "script exists and is executable"
else
  fail "script exists and is executable (missing or not executable: $SCRIPT)"
fi

echo "== case 1: state file present => queries linter with --state, no --transcript =="
rm -rf "$STATE_DIR"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/$SESSION_ID.json"
echo '{"rc":2,"gated":true,"output":"you used a banned word"}' > "$STATE_FILE"
TRANSCRIPT="$WORK/transcript_case1.jsonl"
: > "$TRANSCRIPT"
FAKE_RC=0 FAKE_OUT='previous reply: banned word on line 3' run_hook "$(hook_json "$SESSION_ID" "$TRANSCRIPT")"
assert_eq "$RC" "0" "case1: exits 0"
assert_valid_json "$OUT" "case1: output is valid JSON"
assert_starts_with "$CTX" "$STATIC_REMINDER" "case1: additionalContext starts with static reminder"
assert_contains "$CTX" "previous reply: banned word on line 3" "case1: additionalContext contains FAKE_OUT"
if [ -f "$ARGV_FILE" ]; then
  ARGV_CONTENT="$(cat "$ARGV_FILE")"
  assert_contains "$ARGV_CONTENT" "--state" "case1: argv contains --state"
  assert_contains "$ARGV_CONTENT" "$STATE_FILE" "case1: argv contains state path"
  assert_contains "$ARGV_CONTENT" "--format model" "case1: argv contains --format model"
  assert_not_contains "$ARGV_CONTENT" "--transcript" "case1: argv does not contain --transcript"
else
  fail "case1: argv recorded (missing: $ARGV_FILE)"
fi

echo "== case 2: state file absent, transcript_path given => queries linter with --transcript =="
rm -rf "$STATE_DIR"
mkdir -p "$STATE_DIR"
TRANSCRIPT="$WORK/transcript_case2.jsonl"
: > "$TRANSCRIPT"
FAKE_RC=0 FAKE_OUT='transcript-derived report' run_hook "$(hook_json "$SESSION_ID" "$TRANSCRIPT")"
assert_eq "$RC" "0" "case2: exits 0"
assert_valid_json "$OUT" "case2: output is valid JSON"
assert_contains "$CTX" "transcript-derived report" "case2: additionalContext contains FAKE_OUT"
if [ -f "$ARGV_FILE" ]; then
  ARGV_CONTENT="$(cat "$ARGV_FILE")"
  assert_contains "$ARGV_CONTENT" "--transcript $TRANSCRIPT --last-assistant" "case2: argv contains --transcript <path> --last-assistant"
  assert_contains "$ARGV_CONTENT" "--format model" "case2: argv contains --format model"
  assert_contains "$ARGV_CONTENT" "--scope main" "case2: argv contains --scope main"
else
  fail "case2: argv recorded (missing: $ARGV_FILE)"
fi

echo "== case 3: state absent, transcript absent => no linter invocation =="
rm -rf "$STATE_DIR"
mkdir -p "$STATE_DIR"
NO_TRANSCRIPT="$WORK/does-not-exist.jsonl"
FAKE_RC=0 FAKE_OUT='should not appear' run_hook "$(hook_json "$SESSION_ID" "$NO_TRANSCRIPT")"
assert_eq "$RC" "0" "case3: exits 0"
assert_valid_json "$OUT" "case3: output is valid JSON"
assert_eq "$([ -f "$ARGV_FILE" ] && echo present || echo absent)" "absent" "case3: lint.argv not created"
assert_starts_with "$CTX" "$STATIC_REMINDER" "case3: additionalContext starts with static reminder"
assert_contains "$CTX" "STE block-class checks:" "case3: additionalContext contains rules block heading"

echo "== case 4: rules block lists block-class rows, not warn-class rows =="
assert_contains "$CTX" "FIX-ONE: Fix instruction one." "case4: contains FIX-ONE id and fix"
assert_contains "$CTX" "FIX-TWO: Fix instruction two." "case4: contains FIX-TWO id and fix"
assert_not_contains "$CTX" "WARN-ONE" "case4: does not contain warn-class row id"

echo "== case 5: linter missing => resilient, no error text leaks =="
rm -rf "$STATE_DIR"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/$SESSION_ID.json"
echo '{"rc":0,"gated":false,"output":""}' > "$STATE_FILE"
TRANSCRIPT="$WORK/transcript_case5.jsonl"
: > "$TRANSCRIPT"
run_hook_with_lintbin "$(hook_json "$SESSION_ID" "$TRANSCRIPT")" "/nonexistent/claude-ste-lint.py"
assert_eq "$RC" "0" "case5: exits 0"
assert_valid_json "$OUT" "case5: output is valid JSON"
assert_starts_with "$CTX" "$STATIC_REMINDER" "case5: additionalContext starts with static reminder"
assert_not_contains "$OUT" "No such file" "case5: no 'No such file' text leaks into output"

echo "== case 6: fake linter exits 3 => its output is discarded =="
rm -rf "$STATE_DIR"
mkdir -p "$STATE_DIR"
TRANSCRIPT="$WORK/transcript_case6.jsonl"
: > "$TRANSCRIPT"
FAKE_RC=3 FAKE_OUT='weird crash output' run_hook "$(hook_json "$SESSION_ID" "$TRANSCRIPT")"
assert_eq "$RC" "0" "case6: exits 0"
assert_not_contains "$CTX" "weird crash output" "case6: FAKE_OUT from rc=3 does not appear"
assert_starts_with "$CTX" "$STATIC_REMINDER" "case6: additionalContext starts with static reminder"

echo "== case 7: empty stdin =="
run_hook_empty_stdin
assert_eq "$RC" "0" "case7: exits 0"
assert_valid_json "$OUT" "case7: output is valid JSON"
assert_starts_with "$CTX" "$STATIC_REMINDER" "case7: additionalContext starts with static reminder"

echo "== case 8: top-level shape is exactly hookSpecificOutput with hookEventName/additionalContext =="
TOP_KEYS="$(printf '%s' "$OUT" | jq -c 'keys')"
assert_eq "$TOP_KEYS" '["hookSpecificOutput"]' "case8: top level has only hookSpecificOutput"
INNER_KEYS="$(printf '%s' "$OUT" | jq -c '.hookSpecificOutput | keys')"
assert_eq "$INNER_KEYS" '["additionalContext","hookEventName"]' "case8: hookSpecificOutput has only hookEventName/additionalContext"
EVENT_NAME="$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.hookEventName')"
assert_eq "$EVENT_NAME" "UserPromptSubmit" "case8: hookEventName == UserPromptSubmit"

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

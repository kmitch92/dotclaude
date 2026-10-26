#!/usr/bin/env bash
# Behavioral tests for claude-terse-reminder.sh (UserPromptSubmit hook).
#
# Contract: reads hook JSON on stdin ({session_id, transcript_path, cwd,
# hook_event_name}). Emits exactly one JSON object on stdout:
# {"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"<text>"}}.
# additionalContext is built from:
#   1. the static STATIC_REMINDER sentence block (unchanged, starts "Style
#      reminder: ~/.claude/output-styles/terse.md."), always exactly one
#      line.
#   2. a previous-reply report from STE_LINT_BIN: if STE_STATE_DIR/<session_id>.json
#      exists, its stdout is `LINTER --state <file> --format model`; else if
#      transcript_path exists, `LINTER --transcript <path> --last-assistant
#      --format model --scope main`; on linter missing/not-executable/exit
#      code outside 0/1, this part is empty (no error text leaks into context).
#      That report is then collapsed: rule ids (from rules.tsv) are counted
#      across its lines, sorted by count descending, and only the top 3 are
#      printed, one line each, as "<ID> x<count>: <fix from rules.tsv>". A
#      clean/empty report adds nothing.
#   3. the whole additionalContext is capped at 6 lines total.
# Always exits 0 and prints valid JSON, even on empty/invalid stdin.
#
# Stubbed env: HOME is a throwaway dir. A fake linter at $WORK/fakelint.sh
# records its argv to $WORK/lint.argv and behaves per env FAKE_RC / FAKE_OUT.
# A rules.tsv fixture with 7 ids lives at $WORK/rules.tsv.

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

assert_le() {
  local actual="$1" max="$2" msg="$3"
  if [ "$actual" -le "$max" ]; then
    pass "$msg"
  else
    fail "$msg (expected <= $max, got $actual)"
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
printf 'ID-A\t1.1\tblock\tall\tMessage A\tFix A.\n' >> "$RULES_FILE"
printf 'ID-B\t1.2\tblock\tall\tMessage B\tFix B.\n' >> "$RULES_FILE"
printf 'ID-C\t1.3\twarn\tall\tMessage C\tFix C.\n' >> "$RULES_FILE"
printf 'ID-D\t1.4\twarn\tall\tMessage D\tFix D.\n' >> "$RULES_FILE"
printf 'ID-E\t1.5\twarn\tall\tMessage E\tFix E.\n' >> "$RULES_FILE"
printf 'ID-F\t1.6\twarn\tall\tMessage F\tFix F.\n' >> "$RULES_FILE"
printf 'ID-G\t1.7\twarn\tall\tMessage G\tFix G.\n' >> "$RULES_FILE"

SESSION_ID="SID-TERSE-1"

STATIC_REMINDER="Style reminder: ~/.claude/output-styles/terse.md. One point per reply. Lead with the outcome. Evidence for every claim."

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

echo "== case 1: state file present => queries linter with --state, no --transcript; rc 3 yields no previous-reply feedback =="
rm -rf "$STATE_DIR"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/$SESSION_ID.json"
echo '{"rc":3,"output":"linter failure"}' > "$STATE_FILE"
TRANSCRIPT="$WORK/transcript_case1.jsonl"
: > "$TRANSCRIPT"
FAKE_RC=3 FAKE_OUT='ID-A: weird output from a failing linter run' run_hook "$(hook_json "$SESSION_ID" "$TRANSCRIPT")"
assert_eq "$RC" "0" "case1: exits 0"
assert_valid_json "$OUT" "case1: output is valid JSON"
assert_eq "$CTX" "$STATIC_REMINDER" "case1: additionalContext is only the static reminder (rc 3 => no feedback)"
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
FAKE_RC=0 FAKE_OUT='ID-B: transcript-derived hit' run_hook "$(hook_json "$SESSION_ID" "$TRANSCRIPT")"
assert_eq "$RC" "0" "case2: exits 0"
assert_valid_json "$OUT" "case2: output is valid JSON"
assert_contains "$CTX" "ID-B x1: Fix B." "case2: additionalContext contains collapsed summary line"
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
FAKE_RC=0 FAKE_OUT='ID-A: should not appear' run_hook "$(hook_json "$SESSION_ID" "$NO_TRANSCRIPT")"
assert_eq "$RC" "0" "case3: exits 0"
assert_valid_json "$OUT" "case3: output is valid JSON"
assert_eq "$([ -f "$ARGV_FILE" ] && echo present || echo absent)" "absent" "case3: lint.argv not created"
assert_eq "$CTX" "$STATIC_REMINDER" "case3: additionalContext is only the static reminder"

echo "== case 4: linter missing => resilient, no error text leaks =="
rm -rf "$STATE_DIR"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/$SESSION_ID.json"
echo '{"rc":0,"gated":false,"output":""}' > "$STATE_FILE"
TRANSCRIPT="$WORK/transcript_case4.jsonl"
: > "$TRANSCRIPT"
run_hook_with_lintbin "$(hook_json "$SESSION_ID" "$TRANSCRIPT")" "/nonexistent/claude-ste-lint.py"
assert_eq "$RC" "0" "case4: exits 0"
assert_valid_json "$OUT" "case4: output is valid JSON"
assert_starts_with "$CTX" "$STATIC_REMINDER" "case4: additionalContext starts with static reminder"
assert_not_contains "$OUT" "No such file" "case4: no 'No such file' text leaks into output"

echo "== case 5: fake linter exits 3 => its output is discarded =="
rm -rf "$STATE_DIR"
mkdir -p "$STATE_DIR"
TRANSCRIPT="$WORK/transcript_case5.jsonl"
: > "$TRANSCRIPT"
FAKE_RC=3 FAKE_OUT='ID-A: weird crash output' run_hook "$(hook_json "$SESSION_ID" "$TRANSCRIPT")"
assert_eq "$RC" "0" "case5: exits 0"
assert_not_contains "$CTX" "weird crash output" "case5: FAKE_OUT from rc=3 does not appear"
assert_eq "$CTX" "$STATIC_REMINDER" "case5: additionalContext is only the static reminder"

echo "== case 6: empty stdin =="
run_hook_empty_stdin
assert_eq "$RC" "0" "case6: exits 0"
assert_valid_json "$OUT" "case6: output is valid JSON"
assert_starts_with "$CTX" "$STATIC_REMINDER" "case6: additionalContext starts with static reminder"

echo "== case 7: top-level shape is exactly hookSpecificOutput with hookEventName/additionalContext =="
TOP_KEYS="$(printf '%s' "$OUT" | jq -c 'keys')"
assert_eq "$TOP_KEYS" '["hookSpecificOutput"]' "case7: top level has only hookSpecificOutput"
INNER_KEYS="$(printf '%s' "$OUT" | jq -c '.hookSpecificOutput | keys')"
assert_eq "$INNER_KEYS" '["additionalContext","hookEventName"]' "case7: hookSpecificOutput has only hookEventName/additionalContext"
EVENT_NAME="$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.hookEventName')"
assert_eq "$EVENT_NAME" "UserPromptSubmit" "case7: hookEventName == UserPromptSubmit"

echo "== case 8: clean previous reply (no ids in report) => only the static reminder line =="
rm -rf "$STATE_DIR"
mkdir -p "$STATE_DIR"
TRANSCRIPT="$WORK/transcript_case8.jsonl"
: > "$TRANSCRIPT"
FAKE_RC=0 FAKE_OUT='' run_hook "$(hook_json "$SESSION_ID" "$TRANSCRIPT")"
assert_eq "$RC" "0" "case8: exits 0"
assert_eq "$CTX" "$STATIC_REMINDER" "case8: additionalContext equals the static reminder only"
LINE_COUNT="$(printf '%s\n' "$CTX" | wc -l | tr -d ' ')"
assert_eq "$LINE_COUNT" "1" "case8: additionalContext is exactly one line"

echo "== case 9: 3 distinct ids print in descending count order =="
rm -rf "$STATE_DIR"
mkdir -p "$STATE_DIR"
TRANSCRIPT="$WORK/transcript_case9.jsonl"
: > "$TRANSCRIPT"
FAKE_OUT9="$(for i in $(seq 1 2); do echo "ID-C: hit"; done; for i in $(seq 1 5); do echo "ID-A: hit"; done; for i in $(seq 1 3); do echo "ID-B: hit"; done)"
FAKE_RC=0 FAKE_OUT="$FAKE_OUT9" run_hook "$(hook_json "$SESSION_ID" "$TRANSCRIPT")"
assert_eq "$RC" "0" "case9: exits 0"
SUMMARY_LINES="$(printf '%s\n' "$CTX" | tail -n +2)"
EXPECTED_ORDER="$(printf 'ID-A x5: Fix A.\nID-B x3: Fix B.\nID-C x2: Fix C.')"
assert_eq "$SUMMARY_LINES" "$EXPECTED_ORDER" "case9: ids print highest-count first"

echo "== case 10: 40 hits across 7 ids cap the output at 6 lines =="
rm -rf "$STATE_DIR"
mkdir -p "$STATE_DIR"
TRANSCRIPT="$WORK/transcript_case10.jsonl"
: > "$TRANSCRIPT"
FAKE_OUT10="$(
  for id in ID-A ID-B ID-C ID-D ID-E ID-F ID-G; do :; done
  {
    for i in $(seq 1 10); do echo "ID-A: hit"; done
    for i in $(seq 1 8); do echo "ID-B: hit"; done
    for i in $(seq 1 7); do echo "ID-C: hit"; done
    for i in $(seq 1 6); do echo "ID-D: hit"; done
    for i in $(seq 1 5); do echo "ID-E: hit"; done
    for i in $(seq 1 3); do echo "ID-F: hit"; done
    for i in $(seq 1 1); do echo "ID-G: hit"; done
  }
)"
FAKE_RC=0 FAKE_OUT="$FAKE_OUT10" run_hook "$(hook_json "$SESSION_ID" "$TRANSCRIPT")"
assert_eq "$RC" "0" "case10: exits 0"
LINE_COUNT10="$(printf '%s\n' "$CTX" | wc -l | tr -d ' ')"
assert_le "$LINE_COUNT10" "6" "case10: additionalContext is 6 lines or fewer"
assert_contains "$CTX" "ID-A x10: Fix A." "case10: top id ID-A is present"
assert_not_contains "$CTX" "ID-G" "case10: lowest id ID-G (4th ranked) is dropped"

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

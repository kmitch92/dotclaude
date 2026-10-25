#!/usr/bin/env bash
# Behavioral tests for claude-ste-gate.sh (Stop hook, scope "main").
#
# Contract: reads hook JSON on stdin ({session_id, transcript_path, cwd,
# hook_event_name, stop_hook_active, last_assistant_message}), pipes
# last_assistant_message to the linter (STE_LINT_BIN) on stdin as
# `LINTER --text - --scope main --format model --log --session <id>`.
# Linter exit code: 0 clean, 1 warn, 2 block. On rc 2 with
# stop_hook_active != true and STE_GATE != "warn", prints exactly one JSON
# object {"decision":"block","reason":"<linter stdout verbatim>"} to stdout
# and exits 0. Otherwise prints nothing and exits 0. Writes
# STE_STATE_DIR/<session_id>.json with at least {"rc", "gated", "output"}.
# On linter missing/crash (exit code other than 0/1/2, or not executable),
# exits 0, prints nothing, appends one JSON line with an "error" key to
# STE_LOG. Invalid/empty stdin: exit 0, nothing on stdout. Never exits
# non-zero.
#
# Stubbed env: HOME is a throwaway dir. A fake linter at $WORK/fakelint.sh
# records its argv and stdin, and behaves per env FAKE_RC / FAKE_OUT. The
# real jq is used to parse JSON output.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$TEST_DIR/claude-ste-gate.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/claude-ste-gate-test.XXXXXX")"
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

HOME_DIR="$(mktemp -d "$WORK/home.XXXXXX")"
CWD="$HOME_DIR/proj"
mkdir -p "$CWD"

FAKELINT="$WORK/fakelint.sh"
cat > "$FAKELINT" <<'FAKE'
#!/usr/bin/env bash
# Fake linter: records argv and stdin, exits/prints per env.
printf '%s\n' "$*" > "$FAKE_ARGV_FILE"
cat > "$FAKE_STDIN_FILE"
if [ -n "${FAKE_OUT:-}" ]; then
  printf '%s' "$FAKE_OUT"
fi
exit "${FAKE_RC:-0}"
FAKE
chmod +x "$FAKELINT"

STATE_DIR="$WORK/state"
LOG_FILE="$WORK/lint.log.jsonl"

SESSION_ID="SID-MAIN-1"
MSG=$'line one with a "quote"\nline two üñîçødé'

hook_json() {
  local stop_active="$1" msg="$2"
  jq -cn --arg sid "$SESSION_ID" --arg d "$CWD" --argjson sa "$stop_active" --arg m "$msg" '{
    session_id: $sid, transcript_path: "/tmp/transcript.jsonl", cwd: $d,
    hook_event_name: "Stop", stop_hook_active: $sa, last_assistant_message: $m
  }'
}

RC=0; OUT=""; ERR=""

run_gate() {
  local input="$1" gate_mode="${2:-}"
  rm -f "$WORK/argv" "$WORK/stdin"
  FAKE_ARGV_FILE="$WORK/argv" FAKE_STDIN_FILE="$WORK/stdin" \
    HOME="$HOME_DIR" STE_LINT_BIN="$FAKELINT" STE_STATE_DIR="$STATE_DIR" STE_LOG="$LOG_FILE" \
    STE_GATE="$gate_mode" \
    bash "$SCRIPT" <<< "$input" >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
  ERR="$(cat "$WORK/err")"
}

run_gate_raw_stdin() {
  local input="$1"
  rm -f "$WORK/argv" "$WORK/stdin"
  FAKE_ARGV_FILE="$WORK/argv" FAKE_STDIN_FILE="$WORK/stdin" \
    HOME="$HOME_DIR" STE_LINT_BIN="$FAKELINT" STE_STATE_DIR="$STATE_DIR" STE_LOG="$LOG_FILE" \
    bash "$SCRIPT" <<< "$input" >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
}

run_gate_empty_stdin() {
  rm -f "$WORK/argv" "$WORK/stdin"
  FAKE_ARGV_FILE="$WORK/argv" FAKE_STDIN_FILE="$WORK/stdin" \
    HOME="$HOME_DIR" STE_LINT_BIN="$FAKELINT" STE_STATE_DIR="$STATE_DIR" STE_LOG="$LOG_FILE" \
    bash "$SCRIPT" </dev/null >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
}

echo "== script is present and executable (registered by path) =="
if [ -x "$SCRIPT" ]; then
  pass "script exists and is executable"
else
  fail "script exists and is executable (missing or not executable: $SCRIPT)"
fi

echo "== case 1: rc 2, stop_hook_active false, STE_GATE unset => blocks =="
rm -rf "$STATE_DIR" "$LOG_FILE"
FAKE_RC=2 FAKE_OUT='you used a banned word' run_gate "$(hook_json false "$MSG")"
assert_eq "$RC" "0" "case1: exits 0"
if printf '%s' "$OUT" | jq -e . >/dev/null 2>&1; then
  pass "case1: stdout parses as JSON"
  DECISION="$(printf '%s' "$OUT" | jq -r '.decision')"
  REASON="$(printf '%s' "$OUT" | jq -r '.reason')"
  assert_eq "$DECISION" "block" "case1: .decision == block"
  assert_eq "$REASON" "you used a banned word" "case1: .reason == FAKE_OUT"
else
  fail "case1: stdout parses as JSON (got [$OUT])"
fi
STATE_FILE="$STATE_DIR/$SESSION_ID.json"
if [ -f "$STATE_FILE" ]; then
  pass "case1: state file exists"
  assert_eq "$(jq -r '.gated' "$STATE_FILE")" "true" "case1: state .gated == true"
  assert_eq "$(jq -r '.rc' "$STATE_FILE")" "2" "case1: state .rc == 2"
else
  fail "case1: state file exists (missing: $STATE_FILE)"
fi
if [ -f "$WORK/argv" ]; then
  ARGV_CONTENT="$(cat "$WORK/argv")"
  assert_contains "$ARGV_CONTENT" "--scope main" "case1: argv contains --scope main"
  assert_contains "$ARGV_CONTENT" "--session $SESSION_ID" "case1: argv contains --session $SESSION_ID"
else
  fail "case1: argv recorded (missing: $WORK/argv)"
fi
if [ -f "$WORK/stdin" ]; then
  STDIN_CONTENT="$(cat "$WORK/stdin")"
  assert_eq "$STDIN_CONTENT" "$MSG" "case1: lint.stdin equals last_assistant_message exactly"
else
  fail "case1: lint.stdin recorded (missing: $WORK/stdin)"
fi

echo "== case 2: rc 2, stop_hook_active true => no block =="
rm -rf "$STATE_DIR" "$LOG_FILE"
FAKE_RC=2 FAKE_OUT='banned word' run_gate "$(hook_json true "$MSG")"
assert_eq "$RC" "0" "case2: exits 0"
assert_eq "$OUT" "" "case2: stdout empty"
STATE_FILE="$STATE_DIR/$SESSION_ID.json"
if [ -f "$STATE_FILE" ]; then
  assert_eq "$(jq -r '.gated' "$STATE_FILE")" "false" "case2: state .gated == false"
  assert_eq "$(jq -r '.rc' "$STATE_FILE")" "2" "case2: state .rc == 2"
else
  fail "case2: state file exists (missing: $STATE_FILE)"
fi

echo "== case 3: rc 2, STE_GATE=warn => no block =="
rm -rf "$STATE_DIR" "$LOG_FILE"
FAKE_RC=2 FAKE_OUT='banned word' run_gate "$(hook_json false "$MSG")" "warn"
assert_eq "$RC" "0" "case3: exits 0"
assert_eq "$OUT" "" "case3: stdout empty"
STATE_FILE="$STATE_DIR/$SESSION_ID.json"
if [ -f "$STATE_FILE" ]; then
  assert_eq "$(jq -r '.gated' "$STATE_FILE")" "false" "case3: state .gated == false"
else
  fail "case3: state file exists (missing: $STATE_FILE)"
fi

echo "== case 4: rc 1 => no block, state rc 1 =="
rm -rf "$STATE_DIR" "$LOG_FILE"
FAKE_RC=1 FAKE_OUT='a warning only' run_gate "$(hook_json false "$MSG")"
assert_eq "$RC" "0" "case4: exits 0"
assert_eq "$OUT" "" "case4: stdout empty"
STATE_FILE="$STATE_DIR/$SESSION_ID.json"
if [ -f "$STATE_FILE" ]; then
  assert_eq "$(jq -r '.rc' "$STATE_FILE")" "1" "case4: state .rc == 1"
else
  fail "case4: state file exists (missing: $STATE_FILE)"
fi

echo "== case 5: rc 0 => no block, state rc 0 =="
rm -rf "$STATE_DIR" "$LOG_FILE"
FAKE_RC=0 FAKE_OUT='' run_gate "$(hook_json false "$MSG")"
assert_eq "$RC" "0" "case5: exits 0"
assert_eq "$OUT" "" "case5: stdout empty"
STATE_FILE="$STATE_DIR/$SESSION_ID.json"
if [ -f "$STATE_FILE" ]; then
  assert_eq "$(jq -r '.rc' "$STATE_FILE")" "0" "case5: state .rc == 0"
else
  fail "case5: state file exists (missing: $STATE_FILE)"
fi

echo "== case 6: STE_LINT_BIN points to a non-existent path => resilient =="
rm -rf "$STATE_DIR" "$LOG_FILE"
HOME="$HOME_DIR" STE_LINT_BIN="$WORK/does-not-exist.sh" STE_STATE_DIR="$STATE_DIR" STE_LOG="$LOG_FILE" \
  bash "$SCRIPT" <<< "$(hook_json false "$MSG")" >"$WORK/out" 2>"$WORK/err"
RC=$?
OUT="$(cat "$WORK/out")"
assert_eq "$RC" "0" "case6: exits 0"
assert_eq "$OUT" "" "case6: stdout empty"
if [ -f "$LOG_FILE" ]; then
  LINE_COUNT="$(wc -l < "$LOG_FILE" | tr -d ' ')"
  assert_eq "$LINE_COUNT" "1" "case6: log has exactly one line"
  assert_contains "$(cat "$LOG_FILE")" "error" "case6: log line contains error key"
else
  fail "case6: log file exists (missing: $LOG_FILE)"
fi

echo "== case 7: fake linter exits 3 => resilient =="
rm -rf "$STATE_DIR" "$LOG_FILE"
FAKE_RC=3 FAKE_OUT='weird' run_gate "$(hook_json false "$MSG")"
assert_eq "$RC" "0" "case7: exits 0"
assert_eq "$OUT" "" "case7: stdout empty"
if [ -f "$LOG_FILE" ]; then
  assert_contains "$(cat "$LOG_FILE")" "error" "case7: log line contains error key"
else
  fail "case7: log file exists (missing: $LOG_FILE)"
fi

echo "== case 8: empty stdin => exit 0, nothing on stdout =="
rm -rf "$STATE_DIR" "$LOG_FILE"
FAKE_RC=0 FAKE_OUT='' run_gate_empty_stdin
assert_eq "$RC" "0" "case8: exits 0"
assert_eq "$OUT" "" "case8: stdout empty"

echo "== case 9: stdin JSON without last_assistant_message => exit 0, nothing on stdout =="
rm -rf "$STATE_DIR" "$LOG_FILE"
NO_MSG_JSON="$(jq -cn --arg sid "$SESSION_ID" --arg d "$CWD" '{
  session_id: $sid, transcript_path: "/tmp/transcript.jsonl", cwd: $d,
  hook_event_name: "Stop", stop_hook_active: false
}')"
FAKE_RC=0 FAKE_OUT='' run_gate_raw_stdin "$NO_MSG_JSON"
assert_eq "$RC" "0" "case9: exits 0"
assert_eq "$OUT" "" "case9: stdout empty"

echo "== invalid stdin never blocks =="
rm -rf "$STATE_DIR" "$LOG_FILE"
FAKE_RC=0 FAKE_OUT='' run_gate_raw_stdin '{"session_id": "SID-BAD", "last_assistant_message": "x"'
assert_eq "$RC" "0" "invalid: truncated JSON exits 0"
assert_eq "$OUT" "" "invalid: truncated JSON stdout empty"

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

#!/usr/bin/env bash
# Behavioral tests for claude-ste-subagent-gate.sh (SubagentStop hook, scope
# "sub").
#
# Contract: reads hook JSON on stdin ({session_id, transcript_path, cwd,
# hook_event_name, stop_hook_active, last_assistant_message, agent_id,
# agent_type}), pipes last_assistant_message to the linter (STE_LINT_BIN) on
# stdin as `LINTER --text - --scope sub --format model --log --session
# <agent_id>` (agent_id, not session_id, is used as the id). Linter exit
# code: 0 clean, 1 warn, 2 block. The gate never prints to stdout and never
# blocks the SubagentStop event, for any rc or stop_hook_active value.
# Writes STE_STATE_DIR/<agent_id>.json (NOT session_id.json) with
# {"rc", "output"}. Never exits non-zero.
#
# Stubbed env: HOME is a throwaway dir. A fake linter at $WORK/fakelint.sh
# records its argv and stdin, and behaves per env FAKE_RC / FAKE_OUT. The
# real jq is used to parse JSON output.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$TEST_DIR/claude-ste-subagent-gate.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/claude-ste-subagent-gate-test.XXXXXX")"
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

SESSION_ID="SID-SUB-1"
AGENT_ID="agent-abc"
AGENT_TYPE="worker"
MSG=$'line one with a "quote"\nline two üñîçødé'

hook_json() {
  local stop_active="$1" msg="$2"
  jq -cn --arg sid "$SESSION_ID" --arg d "$CWD" --argjson sa "$stop_active" --arg m "$msg" \
    --arg aid "$AGENT_ID" --arg atype "$AGENT_TYPE" '{
    session_id: $sid, transcript_path: "/tmp/transcript.jsonl", cwd: $d,
    hook_event_name: "SubagentStop", stop_hook_active: $sa, last_assistant_message: $m,
    agent_id: $aid, agent_type: $atype
  }'
}

RC=0; OUT=""

run_gate() {
  local input="$1"
  rm -f "$WORK/argv" "$WORK/stdin"
  FAKE_ARGV_FILE="$WORK/argv" FAKE_STDIN_FILE="$WORK/stdin" \
    HOME="$HOME_DIR" STE_LINT_BIN="$FAKELINT" STE_STATE_DIR="$STATE_DIR" STE_LOG="$LOG_FILE" \
    bash "$SCRIPT" <<< "$input" >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
}

echo "== script is present and executable (registered by path) =="
if [ -x "$SCRIPT" ]; then
  pass "script exists and is executable"
else
  fail "script exists and is executable (missing or not executable: $SCRIPT)"
fi

echo "== case 1: rc 2, stop_hook_active false => records, never blocks =="
rm -rf "$STATE_DIR" "$LOG_FILE"
FAKE_RC=2 FAKE_OUT='you used a banned word' run_gate "$(hook_json false "$MSG")"
assert_eq "$RC" "0" "case1: exits 0"
assert_eq "$OUT" "" "case1: stdout empty"
STATE_FILE="$STATE_DIR/$AGENT_ID.json"
SESSION_STATE_FILE="$STATE_DIR/$SESSION_ID.json"
if [ -f "$STATE_FILE" ]; then
  pass "case1: state file is named agent_id.json"
  assert_eq "$(jq -r '.rc' "$STATE_FILE")" "2" "case1: state .rc == 2"
  assert_eq "$(jq -r '.output' "$STATE_FILE")" "you used a banned word" "case1: state .output == FAKE_OUT"
else
  fail "case1: state file is named agent_id.json (missing: $STATE_FILE)"
fi
if [ -f "$SESSION_STATE_FILE" ]; then
  fail "case1: state file is NOT named session_id.json (unexpectedly found: $SESSION_STATE_FILE)"
else
  pass "case1: state file is NOT named session_id.json"
fi
if [ -f "$WORK/argv" ]; then
  ARGV_CONTENT="$(cat "$WORK/argv")"
  assert_contains "$ARGV_CONTENT" "--scope sub" "case1: argv contains --scope sub"
  assert_contains "$ARGV_CONTENT" "--session $AGENT_ID" "case1: argv contains --session $AGENT_ID (agent_id, not session_id)"
else
  fail "case1: argv recorded (missing: $WORK/argv)"
fi
if [ -f "$WORK/stdin" ]; then
  STDIN_CONTENT="$(cat "$WORK/stdin")"
  assert_eq "$STDIN_CONTENT" "$MSG" "case1: lint.stdin equals last_assistant_message exactly"
else
  fail "case1: lint.stdin recorded (missing: $WORK/stdin)"
fi

echo "== case 2: rc 2, stop_hook_active true => same result, stop_hook_active makes no difference =="
rm -rf "$STATE_DIR" "$LOG_FILE"
FAKE_RC=2 FAKE_OUT='banned word' run_gate "$(hook_json true "$MSG")"
assert_eq "$RC" "0" "case2: exits 0"
assert_eq "$OUT" "" "case2: stdout empty"
STATE_FILE="$STATE_DIR/$AGENT_ID.json"
if [ -f "$STATE_FILE" ]; then
  assert_eq "$(jq -r '.rc' "$STATE_FILE")" "2" "case2: state .rc == 2"
  assert_eq "$(jq -r '.output' "$STATE_FILE")" "banned word" "case2: state .output == FAKE_OUT"
else
  fail "case2: state file exists (missing: $STATE_FILE)"
fi

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

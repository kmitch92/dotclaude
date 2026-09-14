#!/usr/bin/env bash
# Behavioral tests for agent-cap.sh (one script registered for PreToolUse[Agent],
# SubagentStop and SessionStart; dispatches on hook_event_name).
#
# Contract: caps how many `worker` and `scout` subagents a session runs at once.
#   - Caps come from $HOME/.claude/machine.json {"workerCap":N,"scoutCap":M};
#     missing/malformed file -> workerCap 2, scoutCap 6.
#   - PreToolUse Agent below cap: exit 0, count +1, additionalContext lists
#     "worker N/cap" and "scout N/cap". At cap: exit 2, stderr
#     "<type> cap reached (N/cap)".
#   - SubagentStop decrements (never below 0); SessionStart resets its session.
# Counts are observed only through the hook's own output (additionalContext and
# block messages), never by parsing its state files.
# Stubbed env: HOME is a throwaway dir, a stub `claude` is first on PATH and any
# PATH dir holding the real `claude` is stripped. The real jq is used.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$TEST_DIR/agent-cap.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/agent-cap-test.XXXXXX")"
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

assert_empty() {
  local actual="$1" msg="$2"
  if [ -z "$actual" ]; then pass "$msg"; else fail "$msg (expected empty, got [$actual])"; fi
}

SAFE_PATH=""
IFS=: read -r -a PATH_DIRS <<< "$PATH"
for dir in "${PATH_DIRS[@]}"; do
  [ -n "$dir" ] || continue
  [ -x "$dir/claude" ] && continue
  SAFE_PATH="${SAFE_PATH:+$SAFE_PATH:}$dir"
done
if ( PATH="$SAFE_PATH"; command -v claude >/dev/null 2>&1 ); then
  echo "cannot build a PATH free of the real claude CLI; refusing to run" >&2
  exit 1
fi

HOME_DIR=""; BINDIR=""; CWD=""; RC=0; OUT=""; ERR=""

setup_env() {
  HOME_DIR="$(mktemp -d "$WORK/home.XXXXXX")"
  BINDIR="$HOME_DIR/bin"
  CWD="$HOME_DIR/proj"
  mkdir -p "$BINDIR" "$CWD" "$HOME_DIR/.claude"
  cat > "$BINDIR/claude" <<'STUB'
#!/usr/bin/env bash
echo "stub claude: agent-cap.sh must not invoke the claude CLI" >&2
exit 97
STUB
  chmod +x "$BINDIR/claude"
}

write_machine_json() {
  printf '%s\n' "$1" > "$HOME_DIR/.claude/machine.json"
}

run_hook() {
  local input="$1"
  HOME="$HOME_DIR" PATH="$BINDIR:$SAFE_PATH" bash "$SCRIPT" <<< "$input" >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
  ERR="$(cat "$WORK/err")"
}

run_hook_empty_stdin() {
  HOME="$HOME_DIR" PATH="$BINDIR:$SAFE_PATH" bash "$SCRIPT" </dev/null >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
  ERR="$(cat "$WORK/err")"
}

pre_agent_json() {
  local sid="$1" type="$2"
  jq -cn --arg s "$sid" --arg t "$type" --arg c "$CWD" '{
    session_id: $s, cwd: $c, hook_event_name: "PreToolUse",
    tool_name: "Agent", tool_use_id: "toolu_agent_1",
    tool_input: ({description: "task", prompt: "do the task"}
                 + (if $t == "" then {} else {subagent_type: $t} end))
  }'
}

pre_tool_json() {
  local sid="$1" tool="$2"
  jq -cn --arg s "$sid" --arg t "$tool" --arg c "$CWD" '{
    session_id: $s, cwd: $c, hook_event_name: "PreToolUse",
    tool_name: $t, tool_use_id: "toolu_other_1",
    tool_input: {command: "ls", file_path: "/abs/x.ts", subagent_type: "worker"}
  }'
}

subagent_stop_json() {
  local sid="$1" type="$2"
  jq -cn --arg s "$sid" --arg t "$type" --arg c "$CWD" '{
    session_id: $s, cwd: $c, hook_event_name: "SubagentStop",
    stop_hook_active: false, agent_id: "agent_1", agent_type: $t,
    last_assistant_message: "done"
  }'
}

session_start_json() {
  local sid="$1"
  jq -cn --arg s "$sid" --arg c "$CWD" '{
    session_id: $s, cwd: $c, hook_event_name: "SessionStart", source: "startup"
  }'
}

launch() { run_hook "$(pre_agent_json "$1" "$2")"; }
stop_agent() { run_hook "$(subagent_stop_json "$1" "$2")"; }
start_session() { run_hook "$(session_start_json "$1")"; }
context() { printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }

echo "== hook script is present and executable (registered by path) =="
if [ -x "$SCRIPT" ]; then
  pass "script exists and is executable"
else
  fail "script exists and is executable (missing or not executable: $SCRIPT)"
fi

echo "== worker launch below cap is allowed and reports current counts =="
setup_env
launch "SID-A" "worker"
assert_eq "$RC" "0" "below cap: exits 0"
if printf '%s' "$OUT" | jq -e . >/dev/null 2>&1; then
  pass "below cap: stdout is valid JSON"
else
  fail "below cap: stdout is valid JSON (got [$OUT])"
fi
assert_eq "$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.hookEventName // empty' 2>/dev/null)" "PreToolUse" \
  "below cap: hookSpecificOutput.hookEventName is PreToolUse"
assert_contains "$(context)" "worker 1/2" "below cap: additionalContext reports worker 1/2 (default cap)"
assert_contains "$(context)" "scout 0/6" "below cap: additionalContext reports scout 0/6 (default cap)"
if [ -d "$HOME_DIR/.claude/run/agent-caps" ] && [ -n "$(ls -A "$HOME_DIR/.claude/run/agent-caps" 2>/dev/null)" ]; then
  pass "below cap: running counts persisted under \$HOME/.claude/run/agent-caps/"
else
  fail "below cap: running counts persisted under \$HOME/.claude/run/agent-caps/ (dir missing or empty)"
fi

echo "== second worker launch fills the default cap =="
launch "SID-A" "worker"
assert_eq "$RC" "0" "fill cap: second launch exits 0"
assert_contains "$(context)" "worker 2/2" "fill cap: additionalContext reports worker 2/2"

echo "== worker launch at cap is blocked =="
launch "SID-A" "worker"
assert_eq "$RC" "2" "at cap: exits 2"
assert_contains "$ERR" "worker cap reached (2/2)" "at cap: stderr explains worker cap reached (2/2)"

echo "== blocked launch does not consume a slot =="
stop_agent "SID-A" "worker"
assert_eq "$RC" "0" "after block: SubagentStop exits 0"
launch "SID-A" "worker"
assert_eq "$RC" "0" "after block: launch after one stop exits 0"
assert_contains "$(context)" "worker 2/2" "after block: count is back to 2/2, not 3"

echo "== scout uses scoutCap independently of worker =="
setup_env
launch "SID-S" "worker"
launch "SID-S" "worker"
launch "SID-S" "scout"
assert_eq "$RC" "0" "scout: launch allowed while workers are at cap"
assert_contains "$(context)" "scout 1/6" "scout: additionalContext reports scout 1/6"
assert_contains "$(context)" "worker 2/2" "scout: additionalContext still reports worker 2/2"
scout_rcs=""
for _ in 2 3 4 5 6; do
  launch "SID-S" "scout"
  scout_rcs="$scout_rcs$RC"
done
assert_eq "$scout_rcs" "00000" "scout: launches 2..6 all exit 0"
assert_contains "$(context)" "scout 6/6" "scout: sixth launch reports scout 6/6"
launch "SID-S" "scout"
assert_eq "$RC" "2" "scout: seventh launch blocked"
assert_contains "$ERR" "scout cap reached (6/6)" "scout: stderr explains scout cap reached (6/6)"

echo "== filling scouts does not block workers =="
setup_env
for _ in 1 2 3 4 5 6; do launch "SID-S2" "scout"; done
launch "SID-S2" "worker"
assert_eq "$RC" "0" "scouts full: worker launch exits 0"
assert_contains "$(context)" "worker 1/2" "scouts full: reports worker 1/2"
assert_contains "$(context)" "scout 6/6" "scouts full: reports scout 6/6"

echo "== caps are read from \$HOME/.claude/machine.json =="
setup_env
write_machine_json '{"workerCap": 3, "scoutCap": 1}'
launch "SID-M" "worker"
assert_eq "$RC" "0" "machine.json: first worker exits 0"
assert_contains "$(context)" "worker 1/3" "machine.json: reports worker 1/3"
assert_contains "$(context)" "scout 0/1" "machine.json: reports scout 0/1"
launch "SID-M" "worker"
launch "SID-M" "worker"
assert_eq "$RC" "0" "machine.json: third worker exits 0"
assert_contains "$(context)" "worker 3/3" "machine.json: reports worker 3/3"
launch "SID-M" "worker"
assert_eq "$RC" "2" "machine.json: fourth worker blocked"
assert_contains "$ERR" "worker cap reached (3/3)" "machine.json: stderr explains worker cap reached (3/3)"
launch "SID-M" "scout"
assert_eq "$RC" "0" "machine.json: first scout exits 0"
launch "SID-M" "scout"
assert_eq "$RC" "2" "machine.json: second scout blocked"
assert_contains "$ERR" "scout cap reached (1/1)" "machine.json: stderr explains scout cap reached (1/1)"

echo "== malformed machine.json falls back to default caps =="
setup_env
write_machine_json '{"workerCap": 3, "scoutCap":'
launch "SID-BAD" "worker"
assert_eq "$RC" "0" "malformed: worker launch exits 0"
assert_contains "$(context)" "worker 1/2" "malformed: reports default worker 1/2"
assert_contains "$(context)" "scout 0/6" "malformed: reports default scout 0/6"

echo "== non-capped agent types pass through without counting =="
setup_env
launch "SID-O" "general-purpose"
assert_eq "$RC" "0" "other types: general-purpose exits 0"
launch "SID-O" "Explore"
assert_eq "$RC" "0" "other types: Explore exits 0"
launch "SID-O" ""
assert_eq "$RC" "0" "other types: missing subagent_type exits 0"
launch "SID-O" "worker"
assert_contains "$(context)" "worker 1/2" "other types: worker count unaffected (1/2)"
assert_contains "$(context)" "scout 0/6" "other types: scout count unaffected (0/6)"

echo "== tools other than Agent are ignored =="
setup_env
run_hook "$(pre_tool_json "SID-T" "Bash")"
assert_eq "$RC" "0" "other tool: Bash exits 0"
assert_empty "$OUT" "other tool: Bash produces no stdout"
run_hook "$(pre_tool_json "SID-T" "Read")"
assert_eq "$RC" "0" "other tool: Read exits 0"
assert_empty "$OUT" "other tool: Read produces no stdout"
launch "SID-T" "worker"
assert_contains "$(context)" "worker 1/2" "other tool: worker count unaffected (1/2)"

echo "== SubagentStop worker frees a slot =="
setup_env
launch "SID-D" "worker"
launch "SID-D" "worker"
stop_agent "SID-D" "worker"
assert_eq "$RC" "0" "stop: SubagentStop exits 0"
launch "SID-D" "worker"
assert_eq "$RC" "0" "stop: launch after stop exits 0"
assert_contains "$(context)" "worker 2/2" "stop: count went 2 -> 1 -> 2"
stop_agent "SID-D" "worker"
stop_agent "SID-D" "worker"
launch "SID-D" "worker"
assert_contains "$(context)" "worker 1/2" "stop: two stops then launch reports worker 1/2"

echo "== SubagentStop never drops a count below zero =="
setup_env
stop_rcs=""
for _ in 1 2 3; do
  stop_agent "SID-Z" "worker"
  stop_rcs="$stop_rcs$RC"
  stop_agent "SID-Z" "scout"
  stop_rcs="$stop_rcs$RC"
done
assert_eq "$stop_rcs" "000000" "floor: every SubagentStop exits 0"
launch "SID-Z" "worker"
assert_contains "$(context)" "worker 1/2" "floor: worker launch after excess stops reports 1/2"
launch "SID-Z" "scout"
assert_contains "$(context)" "scout 1/6" "floor: scout launch after excess stops reports 1/6"
launch "SID-Z" "worker"
launch "SID-Z" "worker"
assert_eq "$RC" "2" "floor: cap still enforced after excess stops (third worker blocked)"

echo "== SubagentStop scout frees a scout slot only =="
setup_env
write_machine_json '{"workerCap": 2, "scoutCap": 1}'
launch "SID-SS" "worker"
launch "SID-SS" "scout"
stop_agent "SID-SS" "scout"
assert_eq "$RC" "0" "scout stop: exits 0"
launch "SID-SS" "scout"
assert_eq "$RC" "0" "scout stop: scout launch allowed again"
assert_contains "$(context)" "scout 1/1" "scout stop: reports scout 1/1"
assert_contains "$(context)" "worker 1/2" "scout stop: worker count untouched (1/2)"

echo "== SubagentStop for other agent types changes nothing =="
setup_env
launch "SID-X" "worker"
launch "SID-X" "worker"
stop_agent "SID-X" "general-purpose"
assert_eq "$RC" "0" "other stop: general-purpose SubagentStop exits 0"
launch "SID-X" "worker"
assert_eq "$RC" "2" "other stop: workers still at cap (launch blocked)"

echo "== SessionStart resets only its own session =="
setup_env
launch "SID-R1" "worker"
launch "SID-R1" "worker"
launch "SID-R1" "scout"
launch "SID-R2" "worker"
start_session "SID-R1"
assert_eq "$RC" "0" "reset: SessionStart exits 0"
launch "SID-R1" "worker"
assert_eq "$RC" "0" "reset: launch in reset session exits 0"
assert_contains "$(context)" "worker 1/2" "reset: reset session worker count restarted (1/2)"
assert_contains "$(context)" "scout 0/6" "reset: reset session scout count restarted (0/6)"
launch "SID-R2" "worker"
assert_contains "$(context)" "worker 2/2" "reset: other session kept its count (2/2)"

echo "== counts are isolated per session_id =="
setup_env
launch "SID-I1" "worker"
launch "SID-I1" "worker"
launch "SID-I1" "worker"
assert_eq "$RC" "2" "isolation: first session at cap"
launch "SID-I2" "worker"
assert_eq "$RC" "0" "isolation: second session launch exits 0"
assert_contains "$(context)" "worker 1/2" "isolation: second session reports its own count (1/2)"

echo "== concurrent worker launches never exceed workerCap =="
for round in 1 2 3; do
  setup_env
  sid="SID-PAR-$round"
  input="$(pre_agent_json "$sid" "worker")"
  rcdir="$WORK/par-$round"
  mkdir -p "$rcdir"
  for i in 1 2 3 4 5 6; do
    (
      HOME="$HOME_DIR" PATH="$BINDIR:$SAFE_PATH" bash "$SCRIPT" <<< "$input" >/dev/null 2>&1
      printf '%s' "$?" > "$rcdir/$i"
    ) &
  done
  wait
  allowed=0; blocked=0; codes=""
  for i in 1 2 3 4 5 6; do
    code="$(cat "$rcdir/$i" 2>/dev/null || echo missing)"
    codes="$codes $code"
    case "$code" in
      0) allowed=$((allowed + 1)) ;;
      2) blocked=$((blocked + 1)) ;;
    esac
  done
  assert_eq "$allowed" "2" "concurrency round $round: exactly 2 of 6 launches allowed (codes:$codes)"
  assert_eq "$blocked" "4" "concurrency round $round: exactly 4 of 6 launches blocked (codes:$codes)"
  stop_agent "$sid" "worker"
  launch "$sid" "worker"
  assert_eq "$RC" "0" "concurrency round $round: launch after one stop exits 0"
  assert_contains "$(context)" "worker 2/2" "concurrency round $round: final count was exactly 2"
done

echo "== a session lock left by a dead process is recovered =="
setup_env
bash -c 'exit 0' &
dead_pid=$!
wait "$dead_pid"
mkdir -p "$HOME_DIR/.claude/run/agent-caps"
printf '%s\n' "$dead_pid" > "$HOME_DIR/.claude/run/agent-caps/SID-STALE.lock"
launch "SID-STALE" "worker"
assert_eq "$RC" "0" "stale lock: launch exits 0"
assert_contains "$(context)" "worker 1/2" "stale lock: launch was counted (worker 1/2), not waved through uncounted"
launch "SID-STALE" "worker"
assert_contains "$(context)" "worker 2/2" "stale lock: lock released after recovery (next launch reports 2/2)"
launch "SID-STALE" "worker"
assert_eq "$RC" "2" "stale lock: cap still enforced after recovery"

echo "== SubagentStop for other or missing agent_type leaves scouts at cap =="
setup_env
write_machine_json '{"workerCap": 2, "scoutCap": 1}'
launch "SID-XS" "scout"
stop_agent "SID-XS" "Explore"
assert_eq "$RC" "0" "other scout stop: Explore SubagentStop exits 0"
run_hook "$(subagent_stop_json "SID-XS" "" | jq -c 'del(.agent_type)')"
assert_eq "$RC" "0" "other scout stop: SubagentStop without agent_type exits 0"
launch "SID-XS" "scout"
assert_eq "$RC" "2" "other scout stop: scouts still at cap (launch blocked)"
assert_contains "$ERR" "scout cap reached (1/1)" "other scout stop: stderr reports scout cap reached (1/1)"

echo "== invalid stdin never blocks =="
setup_env
run_hook 'this is not json {'
assert_eq "$RC" "0" "invalid: non-JSON stdin exits 0"
run_hook_empty_stdin
assert_eq "$RC" "0" "invalid: empty stdin exits 0"

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

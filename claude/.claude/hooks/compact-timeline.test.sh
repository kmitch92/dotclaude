#!/usr/bin/env bash
# Behavioral tests for compact-timeline.sh.
#
# Contract: compact-timeline.sh TRANSCRIPT_PATH -> markdown on stdout, exit 0.
#   Missing argument or unreadable file -> exit 1, one line on stderr, nothing
#   on stdout. Uses only bash + jq. Reads a Claude Code session transcript
#   (one JSON record per line: human prompts, tool results, assistant
#   messages with tool_use, compaction boundaries, assorted noise records)
#   and emits markdown with exactly seven "## " sections, in order:
#   Asks, Actions, Tests, Errors, Files, Agents, Compactions. See the full
#   field-by-field contract in the worker brief / SPEC this file was written
#   against.
#
# Fixtures are built record-by-record with jq -cn and assembled into
# throwaway .jsonl files under WORK. Assertions only ever look at the
# script's own stdout, stderr and exit code.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$TEST_DIR/compact-timeline.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/compact-timeline-test.XXXXXX")"
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
    fail "$msg (did not expect to contain: [$needle])"
  else
    pass "$msg"
  fi
}

assert_empty() {
  local actual="$1" msg="$2"
  if [ -z "$actual" ]; then pass "$msg"; else fail "$msg (expected empty, got [$actual])"; fi
}

# ---------------------------------------------------------------------------
# record builders (one compact JSON line each, via jq -cn)
# ---------------------------------------------------------------------------

h_prompt() {
  # ts text [sidechain] [meta]
  local ts="$1" text="$2" sc="${3:-false}" meta="${4:-false}"
  jq -cn --arg ts "$ts" --arg text "$text" --argjson sc "$sc" --argjson meta "$meta" '
    {type:"user", message:{role:"user", content:$text}, promptSource:"typed",
     uuid:"u", parentUuid:null, timestamp:$ts, sessionId:"S1",
     isSidechain:$sc, isMeta:$meta}'
}

tool_use_rec() {
  # ts tool_use_id name input_json [sidechain]
  local ts="$1" tid="$2" name="$3" input="$4" sc="${5:-false}"
  jq -cn --arg ts "$ts" --arg tid "$tid" --arg name "$name" --argjson input "$input" --argjson sc "$sc" '
    {type:"assistant",
     message:{role:"assistant", content:[{type:"tool_use", id:$tid, name:$name, input:$input}]},
     uuid:"u", parentUuid:null, timestamp:$ts, sessionId:"S1", isSidechain:$sc}'
}

tool_result_rec() {
  # ts tool_use_id content [is_error] [sidechain]
  local ts="$1" tid="$2" content="$3" err="${4:-false}" sc="${5:-false}"
  jq -cn --arg ts "$ts" --arg tid "$tid" --arg content "$content" --argjson err "$err" --argjson sc "$sc" '
    {type:"user",
     message:{role:"user", content:[{type:"tool_result", tool_use_id:$tid, content:$content, is_error:$err}]},
     toolUseResult:{}, uuid:"u", parentUuid:null, timestamp:$ts, sessionId:"S1", isSidechain:$sc}'
}

compact_boundary_rec() {
  # ts trigger preTokens messagesSummarized
  local ts="$1" trig="$2" pre="$3" msum="$4"
  jq -cn --arg ts "$ts" --arg trig "$trig" --argjson pre "$pre" --argjson msum "$msum" '
    {type:"system", subtype:"compact_boundary", content:"Conversation compacted",
     compactMetadata:{trigger:$trig, preTokens:$pre, messagesSummarized:$msum},
     uuid:"u", parentUuid:null, timestamp:$ts, sessionId:"S1"}'
}

noise_recs() {
  local ts="$1"
  jq -cn --arg ts "$ts" '{type:"mode", mode:"accept-edits", uuid:"u", timestamp:$ts, sessionId:"S1"}'
  jq -cn --arg ts "$ts" '{type:"last-prompt", prompt:"ignored-noise", uuid:"u", timestamp:$ts, sessionId:"S1"}'
  jq -cn --arg ts "$ts" '{type:"ai-title", title:"ignored-noise-title", uuid:"u", timestamp:$ts, sessionId:"S1"}'
  jq -cn --arg ts "$ts" '{type:"attachment", path:"/abs/ignored-noise.png", uuid:"u", timestamp:$ts, sessionId:"S1"}'
  jq -cn --arg ts "$ts" '{type:"system", subtype:"turn_duration", durationMs:1234, uuid:"u", timestamp:$ts, sessionId:"S1"}'
}

# ---------------------------------------------------------------------------
# run helpers
# ---------------------------------------------------------------------------

RC=0; OUT=""; ERR=""

run_raw() {
  bash "$SCRIPT" "$@" >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
  ERR="$(cat "$WORK/err")"
}

run_with_env() {
  local maxact="$1"; shift
  COMPACT_TIMELINE_MAX_ACTIONS="$maxact" bash "$SCRIPT" "$@" >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
  ERR="$(cat "$WORK/err")"
}

extract_section() {
  # extract_section OUTPUT "Section Name" -> body lines between the heading
  # and the next "## " heading (or EOF)
  local text="$1" name="$2"
  printf '%s\n' "$text" | awk -v target="## $name" '
    $0 == target { found=1; next }
    found && /^## / { exit }
    found { print }
  '
}

count_lines_matching() {
  # count_lines_matching TEXT REGEX
  printf '%s\n' "$1" | grep -c -E -- "$2" || true
}

# ===========================================================================
# (1) no args
# ===========================================================================
echo "== no arguments =="
run_raw
assert_eq "$RC" "1" "no args: exits 1"
assert_empty "$OUT" "no args: stdout is empty"
if [ -n "$ERR" ]; then
  pass "no args: stderr is non-empty"
else
  fail "no args: stderr is non-empty (got empty)"
fi
ERR_LINES="$(printf '%s\n' "$ERR" | grep -c .)"
assert_eq "$ERR_LINES" "1" "no args: stderr is exactly one line"

# ===========================================================================
# (2) missing/unreadable file
# ===========================================================================
echo "== missing transcript file =="
MISSING="$WORK/does-not-exist.jsonl"
run_raw "$MISSING"
assert_eq "$RC" "1" "missing file: exits 1"
assert_empty "$OUT" "missing file: stdout is empty"
if [ -n "$ERR" ]; then
  pass "missing file: stderr is non-empty"
else
  fail "missing file: stderr is non-empty (got empty)"
fi

# ===========================================================================
# (3) Asks: filtering and [initial ask]
# ===========================================================================
echo "== Asks: filters noise/system prompts, numbers survivors, tags first as initial ask =="
FIXTURE_3="$WORK/fixture-3.jsonl"
{
  h_prompt "2026-10-07T09:05:00.000Z" $'Please fix bug\nin the parser'
  noise_recs "2026-10-07T09:05:30.000Z"
  h_prompt "2026-10-07T09:06:00.000Z" "Warmup"
  h_prompt "2026-10-07T09:07:00.000Z" "<command-name>/exit</command-name>"
  h_prompt "2026-10-07T09:08:00.000Z" "[Request interrupted by user]"
  h_prompt "2026-10-07T10:30:00.000Z" "Second ask, please also run tests"
} > "$FIXTURE_3"
run_raw "$FIXTURE_3"
assert_eq "$RC" "0" "asks fixture: exits 0"
ASKS_3="$(extract_section "$OUT" "Asks")"
assert_contains "$ASKS_3" "1. 09:05  Please fix bug in the parser  [initial ask]" \
  "asks fixture: first entry collapses the newline and carries [initial ask]"
assert_contains "$ASKS_3" "2. 10:30  Second ask, please also run tests" \
  "asks fixture: second entry has no [initial ask] suffix"
ASKS_3_COUNT="$(count_lines_matching "$ASKS_3" '^[0-9]+\. ')"
assert_eq "$ASKS_3_COUNT" "2" "asks fixture: exactly 2 numbered entries (Warmup/command/interrupted excluded)"
assert_not_contains "$OUT" "ignored-noise" "asks fixture: noise records never surface in output"

# ===========================================================================
# (4) Actions / Errors / Files / Agents across tool types
# ===========================================================================
echo "== Actions/Errors/Files/Agents across Edit, Read, Bash, Agent, Skill =="
FIXTURE_4="$WORK/fixture-4.jsonl"
LONG_CMD="$(printf 'x%.0s' {1..150})"
EXPECTED_LONG_TARGET="${LONG_CMD:0:100}"
{
  tool_use_rec "2026-10-07T09:10:00.000Z" "toolu_edit1" "Edit" '{"file_path":"/abs/a.ts"}'
  tool_result_rec "2026-10-07T09:10:01.000Z" "toolu_edit1" "ok" "false"

  tool_use_rec "2026-10-07T09:11:00.000Z" "toolu_read1" "Read" '{"file_path":"/abs/b.ts"}'
  tool_result_rec "2026-10-07T09:11:01.000Z" "toolu_read1" "read ok" "false"

  tool_use_rec "2026-10-07T09:12:00.000Z" "toolu_bash1" "Bash" \
    '{"command":"npm run build","description":"Build the project"}'
  tool_result_rec "2026-10-07T09:12:01.000Z" "toolu_bash1" "Error: build failed" "true"

  tool_use_rec "2026-10-07T09:13:00.000Z" "toolu_bash2" "Bash" \
    "$(jq -cn --arg c "$LONG_CMD" '{command:$c}')"
  tool_result_rec "2026-10-07T09:13:01.000Z" "toolu_bash2" "hello" "false"

  tool_use_rec "2026-10-07T09:14:00.000Z" "toolu_agent1" "Agent" \
    '{"subagent_type":"scout","description":"find X"}'
  tool_result_rec "2026-10-07T09:14:01.000Z" "toolu_agent1" "found" "false"

  tool_use_rec "2026-10-07T09:15:00.000Z" "toolu_skill1" "Skill" '{"skill":"my-skill"}'
  tool_result_rec "2026-10-07T09:15:01.000Z" "toolu_skill1" "done" "false"

  tool_use_rec "2026-10-07T09:16:00.000Z" "toolu_write1" "Write" '{"file_path":"/abs/a.ts"}'
  tool_result_rec "2026-10-07T09:16:01.000Z" "toolu_write1" "written" "false"

  tool_use_rec "2026-10-07T09:17:00.000Z" "toolu_read2" "Read" '{"file_path":"/abs/a.ts"}'
  tool_result_rec "2026-10-07T09:17:01.000Z" "toolu_read2" "read again" "false"
} > "$FIXTURE_4"
run_raw "$FIXTURE_4"
assert_eq "$RC" "0" "tools fixture: exits 0"

ACTIONS_4="$(extract_section "$OUT" "Actions")"
assert_contains "$ACTIONS_4" "09:10  Edit  /abs/a.ts  ok" "tools fixture: Edit action line"
assert_contains "$ACTIONS_4" "09:11  Read  /abs/b.ts  ok" "tools fixture: Read action line"
assert_contains "$ACTIONS_4" "09:12  Bash  Build the project  ERROR" "tools fixture: Bash-with-description action line is ERROR"
assert_contains "$ACTIONS_4" "09:13  Bash  $EXPECTED_LONG_TARGET  ok" \
  "tools fixture: Bash-without-description falls back to first 100 chars of command"
assert_contains "$ACTIONS_4" "09:14  Agent  scout: find X  ok" "tools fixture: Agent action line"
assert_contains "$ACTIONS_4" "09:15  Skill  my-skill  ok" "tools fixture: Skill action line"
assert_contains "$ACTIONS_4" "09:16  Write  /abs/a.ts  ok" "tools fixture: Write action line"
assert_contains "$ACTIONS_4" "09:17  Read  /abs/a.ts  ok" "tools fixture: second Read action line"

ERRORS_4="$(extract_section "$OUT" "Errors")"
assert_contains "$ERRORS_4" "09:12  Bash  Error: build failed" "tools fixture: Errors lists the failed Bash result"
assert_not_contains "$ERRORS_4" "none" "tools fixture: Errors section is not \"none\" when a failure exists"

FILES_4="$(extract_section "$OUT" "Files")"
assert_contains "$FILES_4" "edited:" "tools fixture: Files has an edited: sub-list"
assert_contains "$FILES_4" "read:" "tools fixture: Files has a read: sub-list"
assert_contains "$FILES_4" "/abs/a.ts" "tools fixture: Files edited list contains /abs/a.ts"
assert_contains "$FILES_4" "/abs/b.ts" "tools fixture: Files read list contains /abs/b.ts"
A_TS_COUNT="$(printf '%s\n' "$FILES_4" | grep -o -F '/abs/a.ts' | wc -l | tr -d ' ')"
assert_eq "$A_TS_COUNT" "1" \
  "tools fixture: /abs/a.ts (edited twice, read once) appears exactly once across Files, deduped into edited only"

AGENTS_4="$(extract_section "$OUT" "Agents")"
assert_contains "$AGENTS_4" "09:14  scout  find X  ok" "tools fixture: Agents line for the scout dispatch"

TESTS_4="$(extract_section "$OUT" "Tests")"
assert_contains "$TESTS_4" "none" "tools fixture: Tests section is none (no test-like commands present)"

# ===========================================================================
# (5) Tests section: matching vs non-matching Bash commands
# ===========================================================================
echo "== Tests: test-matching Bash commands show last 3 result lines, others are excluded =="
FIXTURE_5="$WORK/fixture-5.jsonl"
MULTILINE_RESULT=$'line1\nline2\nline3\nline4\nline5'
{
  tool_use_rec "2026-10-07T09:20:00.000Z" "toolu_test1" "Bash" '{"command":"bash /x/y.test.sh"}'
  tool_result_rec "2026-10-07T09:20:01.000Z" "toolu_test1" "$MULTILINE_RESULT" "false"

  tool_use_rec "2026-10-07T09:21:00.000Z" "toolu_ls1" "Bash" '{"command":"ls -la"}'
  tool_result_rec "2026-10-07T09:21:01.000Z" "toolu_ls1" "total 0" "false"
} > "$FIXTURE_5"
run_raw "$FIXTURE_5"
assert_eq "$RC" "0" "tests fixture: exits 0"
TESTS_5="$(extract_section "$OUT" "Tests")"
assert_contains "$TESTS_5" "09:20  bash /x/y.test.sh  ok" "tests fixture: test command line present with ok status"
assert_contains "$TESTS_5" "  line3" "tests fixture: shows 3rd-from-last non-empty result line, indented"
assert_contains "$TESTS_5" "  line4" "tests fixture: shows 2nd-from-last non-empty result line, indented"
assert_contains "$TESTS_5" "  line5" "tests fixture: shows last non-empty result line, indented"
assert_not_contains "$TESTS_5" "line1" "tests fixture: does not show the 1st (non-last-3) result line"
assert_not_contains "$TESTS_5" "line2" "tests fixture: does not show the 2nd (non-last-3) result line"
assert_not_contains "$TESTS_5" "ls -la" "tests fixture: a plain ls command does not match the test regex"

# ===========================================================================
# (6) tool_use with no matching tool_result
# ===========================================================================
echo "== Actions: tool_use with no matching tool_result reports \"no result\" =="
FIXTURE_6="$WORK/fixture-6.jsonl"
{
  tool_use_rec "2026-10-07T09:25:00.000Z" "toolu_orphan" "Bash" \
    '{"command":"something","description":"orphan action"}'
} > "$FIXTURE_6"
run_raw "$FIXTURE_6"
assert_eq "$RC" "0" "orphan fixture: exits 0"
ACTIONS_6="$(extract_section "$OUT" "Actions")"
assert_contains "$ACTIONS_6" "09:25  Bash  orphan action  no result" "orphan fixture: status is \"no result\""

# ===========================================================================
# (7) Compactions
# ===========================================================================
echo "== Compactions: counts and lists boundaries, or reports none =="
FIXTURE_7A="$WORK/fixture-7a.jsonl"
{
  compact_boundary_rec "2026-10-07T09:30:00.000Z" "auto" "180000" "120"
  compact_boundary_rec "2026-10-07T09:35:00.000Z" "manual" "95000" "40"
} > "$FIXTURE_7A"
run_raw "$FIXTURE_7A"
assert_eq "$RC" "0" "compactions fixture: exits 0"
COMPACT_7A="$(extract_section "$OUT" "Compactions")"
assert_contains "$COMPACT_7A" "2 prior compaction(s)" "compactions fixture: reports 2 prior compactions"
assert_contains "$COMPACT_7A" "09:30  trigger=auto  preTokens=180000  summarised=120" \
  "compactions fixture: first boundary line"
assert_contains "$COMPACT_7A" "09:35  trigger=manual  preTokens=95000  summarised=40" \
  "compactions fixture: second boundary line"

FIXTURE_7B="$WORK/fixture-7b.jsonl"
{
  h_prompt "2026-10-07T09:40:00.000Z" "No compactions here"
} > "$FIXTURE_7B"
run_raw "$FIXTURE_7B"
assert_eq "$RC" "0" "no-compactions fixture: exits 0"
COMPACT_7B="$(extract_section "$OUT" "Compactions")"
assert_contains "$COMPACT_7B" "none" "no-compactions fixture: Compactions section is none"

# ===========================================================================
# (8) COMPACT_TIMELINE_MAX_ACTIONS drops older actions
# ===========================================================================
echo "== Actions: COMPACT_TIMELINE_MAX_ACTIONS drops the oldest actions beyond the cap =="
FIXTURE_8="$WORK/fixture-8.jsonl"
{
  tool_use_rec "2026-10-07T09:40:00.000Z" "toolu_cap1" "Read" '{"file_path":"/abs/1.ts"}'
  tool_result_rec "2026-10-07T09:40:01.000Z" "toolu_cap1" "ok1" "false"

  tool_use_rec "2026-10-07T09:41:00.000Z" "toolu_cap2" "Read" '{"file_path":"/abs/2.ts"}'
  tool_result_rec "2026-10-07T09:41:01.000Z" "toolu_cap2" "ok2" "false"

  tool_use_rec "2026-10-07T09:42:00.000Z" "toolu_cap3" "Read" '{"file_path":"/abs/3.ts"}'
  tool_result_rec "2026-10-07T09:42:01.000Z" "toolu_cap3" "ok3" "false"

  tool_use_rec "2026-10-07T09:43:00.000Z" "toolu_cap4" "Read" '{"file_path":"/abs/4.ts"}'
  tool_result_rec "2026-10-07T09:43:01.000Z" "toolu_cap4" "ok4" "false"
} > "$FIXTURE_8"
run_with_env "2" "$FIXTURE_8"
assert_eq "$RC" "0" "cap fixture: exits 0"
ACTIONS_8="$(extract_section "$OUT" "Actions")"
assert_contains "$ACTIONS_8" "(dropped 2 older actions)" "cap fixture: reports dropped count"
assert_contains "$ACTIONS_8" "09:42  Read  /abs/3.ts  ok" "cap fixture: keeps newest-but-one action"
assert_contains "$ACTIONS_8" "09:43  Read  /abs/4.ts  ok" "cap fixture: keeps newest action"
assert_not_contains "$ACTIONS_8" "/abs/1.ts" "cap fixture: drops oldest action"
assert_not_contains "$ACTIONS_8" "/abs/2.ts" "cap fixture: drops second-oldest action"
FIRST_ACTIONS_LINE="$(printf '%s\n' "$ACTIONS_8" | grep -m1 .)"
assert_eq "$FIRST_ACTIONS_LINE" "(dropped 2 older actions)" \
  "cap fixture: dropped-count line is the first line of the Actions section"

# ===========================================================================
# (9) isSidechain is excluded from Asks and Actions
# ===========================================================================
echo "== isSidechain records are excluded from Asks and Actions =="
FIXTURE_9="$WORK/fixture-9.jsonl"
{
  h_prompt "2026-10-07T09:50:00.000Z" "Sidechain ask should be ignored" "true"
  h_prompt "2026-10-07T09:51:00.000Z" "Real ask should appear" "false"

  tool_use_rec "2026-10-07T09:52:00.000Z" "toolu_side1" "Read" '{"file_path":"/abs/sidechain.ts"}' "true"
  tool_result_rec "2026-10-07T09:52:01.000Z" "toolu_side1" "side ok" "false" "true"

  tool_use_rec "2026-10-07T09:53:00.000Z" "toolu_main1" "Read" '{"file_path":"/abs/main.ts"}' "false"
  tool_result_rec "2026-10-07T09:53:01.000Z" "toolu_main1" "main ok" "false" "false"
} > "$FIXTURE_9"
run_raw "$FIXTURE_9"
assert_eq "$RC" "0" "sidechain fixture: exits 0"
ASKS_9="$(extract_section "$OUT" "Asks")"
assert_contains "$ASKS_9" "1. 09:51  Real ask should appear  [initial ask]" \
  "sidechain fixture: the only counted ask is the non-sidechain one, tagged initial"
ASKS_9_COUNT="$(count_lines_matching "$ASKS_9" '^[0-9]+\. ')"
assert_eq "$ASKS_9_COUNT" "1" "sidechain fixture: exactly 1 ask (sidechain prompt excluded)"
ACTIONS_9="$(extract_section "$OUT" "Actions")"
assert_not_contains "$ACTIONS_9" "/abs/sidechain.ts" "sidechain fixture: sidechain tool_use excluded from Actions"
assert_contains "$ACTIONS_9" "/abs/main.ts" "sidechain fixture: non-sidechain tool_use present in Actions"

# ===========================================================================
# (10) section order
# ===========================================================================
echo "== output sections appear in the fixed order =="
run_raw "$FIXTURE_4"
assert_eq "$RC" "0" "order check: exits 0"
HEADINGS="$(printf '%s\n' "$OUT" | grep '^## ' | sed 's/^## //' | tr '\n' ',' | sed 's/,$//')"
assert_eq "$HEADINGS" "Asks,Actions,Tests,Errors,Files,Agents,Compactions" \
  "order check: the seven headings appear in the specified order"

echo

# ===========================================================================
# (11) Asks: typed slash commands are excluded, slash-containing text is not
# ===========================================================================
echo "== Asks: typed slash commands (e.g. /compact) excluded; slash-in-text prompts kept =="
FIXTURE_11="$WORK/fixture-11.jsonl"
{
  h_prompt "2026-10-07T11:00:00.000Z" "fix the hook"
  h_prompt "2026-10-07T11:01:00.000Z" "/compact"
  h_prompt "2026-10-07T11:02:00.000Z" "/model fable"
  h_prompt "2026-10-07T11:03:00.000Z" "/tmp/foo is a path"
  h_prompt "2026-10-07T11:04:00.000Z" "run /compact later"
} > "$FIXTURE_11"
run_raw "$FIXTURE_11"
assert_eq "$RC" "0" "slash fixture: exits 0"
ASKS_11="$(extract_section "$OUT" "Asks")"
assert_contains "$ASKS_11" "1. 11:00  fix the hook  [initial ask]" \
  "slash fixture: first entry is the real ask, tagged initial"
assert_not_contains "$ASKS_11" "11:01" "slash fixture: typed /compact excluded (no 11:01 entry)"
assert_not_contains "$ASKS_11" "11:02" "slash fixture: typed /model fable excluded (no 11:02 entry)"
assert_contains "$ASKS_11" "/tmp/foo is a path" "slash fixture: /tmp/foo is a path is kept"
assert_contains "$ASKS_11" "run /compact later" "slash fixture: run /compact later is kept"
ASKS_11_COUNT="$(count_lines_matching "$ASKS_11" '^[0-9]+\. ')"
assert_eq "$ASKS_11_COUNT" "3" "slash fixture: exactly 3 numbered entries"

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

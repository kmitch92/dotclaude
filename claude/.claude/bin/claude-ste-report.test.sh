#!/usr/bin/env bash
# Behavioral tests for claude-ste-report.sh (summarises the STE lint log).
#
# Contract: `claude-ste-report.sh [--log PATH] [--days N]`. Default PATH is
# $STE_LOG or $HOME/.claude/ste/lint.log.jsonl. --days N keeps only lines
# with ts within the last N days relative to now. Plain text output, in
# order: "lints: <n>" (count of event=="lint" lines, any scope);
# "hit rate: <pct>%" (rc==2 lint events / all lint events, integer
# percent); "gate errors: <n>" (count of event=="gate-error" lines);
# "register hits:" then one line each for NARRATION, FILLER-OPEN and SLOP
# (summed from every event's "counts" object); "top ids:" then up to 10
# lines "  <ID> <count>" sorted desc by count (summed over every event's
# "counts" object); "top slop:" then up to 20 lines
# "  <phrase> <count> -> <hint>" from warn or block entries with id SLOP,
# grouped by phrase; "prose words: min <a> median <b> max <c>" over
# main-scope lint events' prose_words field (median = average of the two
# middle values when the count is even). Missing or empty log ->
# "lints: 0", exit 0.
#
# Fixture: claude/.claude/ste/tests/fixtures/lint.log.sample.jsonl, 10
# lines: 6 main lint events (sessions s1 x5, s2 x1), 2 sub lint events
# (rc 1), 2 gate-error lines. Every id in the fixture is one of the 13
# current rule ids (see ste/rules.tsv); no rule has class "block", so
# every hit sits in "warn" and every "block" array is empty. SLOP is the
# most frequent id, so "top ids" and "top slop" both have data. Rc is 0
# (no hits) or 1 (at least one hit) on every line; rc 2 never occurs, so
# hit rate is 0%. Hand-computed expectations:
#   lints: 8
#   hit rate: 0%   (rc==2 count 0 / lints 8, no rule blocks)
#   gate errors: 2
#   register hits:              NARRATION 1, FILLER-OPEN 1, SLOP 5
#   top ids first line:        SLOP 5
#   prose words: min 40 median 87.5 max 200
#
# jq is required by the implementation; this test does not stub or hide
# the real jq.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$TEST_DIR/claude-ste-report.sh"
FIXTURE="$(cd "$TEST_DIR/../ste/tests/fixtures" && pwd)/lint.log.sample.jsonl"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/claude-ste-report-test.XXXXXX")"
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

RC=0; OUT=""

run_report() {
  "$SCRIPT" "$@" >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
}

echo "== script is present and executable =="
if [ -x "$SCRIPT" ]; then
  pass "script exists and is executable"
else
  fail "script exists and is executable (missing or not executable: $SCRIPT)"
fi

echo "== case 1: --log points at a missing file => lints: 0, exit 0 =="
run_report --log "$WORK/does-not-exist.jsonl"
assert_eq "$RC" "0" "case1: exits 0"
assert_contains "$OUT" "lints: 0" "case1: reports lints: 0"

echo "== case 2: --log points at an empty file => lints: 0, exit 0 =="
: > "$WORK/empty.jsonl"
run_report --log "$WORK/empty.jsonl"
assert_eq "$RC" "0" "case2: exits 0"
assert_contains "$OUT" "lints: 0" "case2: reports lints: 0"

echo "== case 3: fixture log, full summary =="
run_report --log "$FIXTURE"
assert_eq "$RC" "0" "case3: exits 0"
assert_contains "$OUT" "lints: 8" "case3: lints 8"
assert_contains "$OUT" "hit rate: 0%" "case3: hit rate 0%"
assert_contains "$OUT" "gate errors: 2" "case3: gate errors 2"
assert_contains "$OUT" "register hits:" "case3: has register hits section"
assert_contains "$OUT" "  NARRATION 1" "case3: register hits NARRATION 1"
assert_contains "$OUT" "  FILLER-OPEN 1" "case3: register hits FILLER-OPEN 1"
assert_contains "$OUT" "  SLOP 5" "case3: register hits SLOP 5"
assert_contains "$OUT" "top ids:" "case3: has top ids section"
assert_contains "$OUT" "  SLOP 5" "case3: top ids includes SLOP 5"
assert_contains "$OUT" "top slop:" "case3: has top slop section"
assert_contains "$OUT" "  very 3 -> Name the property you mean, or delete the word." "case3: top slop includes very 3"
assert_contains "$OUT" "  really 2 -> Name the property you mean, or delete the word." "case3: top slop includes really 2"
assert_contains "$OUT" "prose words: min 40 median 87.5 max 200" "case3: prose words min/median/max"

echo "== case 4: top ids SLOP is the first line of its section =="
run_report --log "$FIXTURE"
TOP_IDS_FIRST="$(printf '%s\n' "$OUT" | awk '/^top ids:$/{getline; print; exit}')"
assert_eq "$TOP_IDS_FIRST" "  SLOP 5" "case4: first top-ids line is SLOP 5"

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

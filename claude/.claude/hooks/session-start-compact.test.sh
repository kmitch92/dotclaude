#!/usr/bin/env bash
# Behavioral tests for session-start-compact.sh (a SessionStart hook).
#
# Contract: on SessionStart with source == "compact", if a sidecar file
# $HOME/.claude/run/compact/<session_id>.md exists, prints its content
# (prefixed with a fixed header line) as hookSpecificOutput.additionalContext
# and exits 0. For any other source, missing/empty session_id, missing or
# non-JSON stdin, or a missing sidecar, it prints nothing and exits 0.
# Content over 24000 chars is truncated with a pointer back to the sidecar
# path. The sidecar is never modified or deleted by the hook.
# Stubbed env: HOME is a throwaway dir, a stub `claude` is first on PATH and
# any PATH dir holding the real `claude` is stripped (the hook must never
# invoke it). The real jq is used.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$TEST_DIR/session-start-compact.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/session-start-compact-test.XXXXXX")"
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
    fail "$msg (expected NOT to contain: [$needle])"
  else
    pass "$msg"
  fi
}

assert_empty() {
  local actual="$1" msg="$2"
  if [ -z "$actual" ]; then pass "$msg"; else fail "$msg (expected empty, got [$actual])"; fi
}

HEADER="Machine-generated action log for this session, captured just before compaction. Treat it as authoritative over the summary where they disagree."

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

HOME_DIR=""; BINDIR=""; CWD=""; COMPACT_DIR=""; RC=0; OUT=""; ERR=""

setup_env() {
  HOME_DIR="$(mktemp -d "$WORK/home.XXXXXX")"
  BINDIR="$HOME_DIR/bin"
  CWD="$HOME_DIR/proj"
  COMPACT_DIR="$HOME_DIR/.claude/run/compact"
  mkdir -p "$BINDIR" "$CWD" "$HOME_DIR/.claude"
  cat > "$BINDIR/claude" <<'STUB'
#!/usr/bin/env bash
echo "stub claude: session-start-compact.sh must not invoke the claude CLI" >&2
exit 97
STUB
  chmod +x "$BINDIR/claude"
}

write_sidecar() {
  local sid="$1" content="$2"
  mkdir -p "$COMPACT_DIR"
  printf '%s' "$content" > "$COMPACT_DIR/$sid.md"
}

sidecar_path() {
  local sid="$1"
  printf '%s' "$COMPACT_DIR/$sid.md"
}

session_start_json() {
  local sid="$1" source="$2"
  jq -cn --arg s "$sid" --arg c "$CWD" --arg src "$source" --arg tp "$HOME_DIR/transcript.jsonl" '{
    session_id: $s, transcript_path: $tp, cwd: $c,
    hook_event_name: "SessionStart", source: $src
  }'
}

session_start_json_no_sid() {
  local source="$1"
  jq -cn --arg c "$CWD" --arg src "$source" --arg tp "$HOME_DIR/transcript.jsonl" '{
    transcript_path: $tp, cwd: $c, hook_event_name: "SessionStart", source: $src
  }'
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

start() { run_hook "$(session_start_json "$1" "$2")"; }
context() { printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }

echo "== script is present and executable (registered by path) =="
if [ -x "$SCRIPT" ]; then
  pass "script exists and is executable"
else
  fail "script exists and is executable (missing or not executable: $SCRIPT)"
fi

echo "== source compact with sidecar present injects context =="
setup_env
write_sidecar "SID-A" "hello world log entry"
start "SID-A" "compact"
assert_eq "$RC" "0" "compact+sidecar: exits 0"
if printf '%s' "$OUT" | jq -e . >/dev/null 2>&1; then
  pass "compact+sidecar: stdout is valid JSON"
else
  fail "compact+sidecar: stdout is valid JSON (got [$OUT])"
fi
assert_eq "$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.hookEventName // empty' 2>/dev/null)" "SessionStart" \
  "compact+sidecar: hookSpecificOutput.hookEventName is SessionStart"
assert_contains "$(context)" "$HEADER" "compact+sidecar: additionalContext contains the header line"
assert_contains "$(context)" "hello world log entry" "compact+sidecar: additionalContext contains the sidecar content"

echo "== non-compact sources produce no output even with a sidecar present =="
for src in startup resume clear fork; do
  start "SID-A" "$src"
  assert_eq "$RC" "0" "source $src: exits 0"
  assert_empty "$OUT" "source $src: stdout is empty"
done

echo "== source compact with no sidecar produces no output =="
setup_env
start "SID-NONE" "compact"
assert_eq "$RC" "0" "no sidecar: exits 0"
assert_empty "$OUT" "no sidecar: stdout is empty"

echo "== empty stdin produces no output =="
setup_env
run_hook_empty_stdin
assert_eq "$RC" "0" "empty stdin: exits 0"
assert_empty "$OUT" "empty stdin: stdout is empty"

echo "== non-JSON stdin produces no output =="
setup_env
run_hook 'this is not json {'
assert_eq "$RC" "0" "non-JSON stdin: exits 0"
assert_empty "$OUT" "non-JSON stdin: stdout is empty"

echo "== missing or empty session_id produces no output =="
setup_env
write_sidecar "" "orphan content"
run_hook "$(session_start_json_no_sid "compact")"
assert_eq "$RC" "0" "missing session_id: exits 0"
assert_empty "$OUT" "missing session_id: stdout is empty"
start "" "compact"
assert_eq "$RC" "0" "empty session_id: exits 0"
assert_empty "$OUT" "empty session_id: stdout is empty"

echo "== oversized sidecar is truncated with a pointer to the full file =="
setup_env
MARKER="ZZEND_MARKER_UNIQUE_9981ZZ"
FILLER="$(yes A | tr -d '\n' | head -c $((30000 - ${#MARKER})))"
BIG_CONTENT="${FILLER}${MARKER}"
assert_eq "${#BIG_CONTENT}" "30000" "fixture sanity: big content is exactly 30000 chars"
write_sidecar "SID-BIG" "$BIG_CONTENT"
SIDECAR_BIG="$(sidecar_path "SID-BIG")"
start "SID-BIG" "compact"
assert_eq "$RC" "0" "truncation: exits 0"
BIG_CTX="$(context)"
assert_contains "$BIG_CTX" "[truncated; full log at " "truncation: contains the truncation marker line"
assert_contains "$BIG_CTX" "$SIDECAR_BIG" "truncation: contains the absolute sidecar path"
assert_not_contains "$BIG_CTX" "$MARKER" "truncation: does not contain content past position 24000"
if [ "${#BIG_CTX}" -gt 24000 ] && [ "${#BIG_CTX}" -lt 25500 ]; then
  pass "truncation: additionalContext length is bounded (got ${#BIG_CTX})"
else
  fail "truncation: additionalContext length is bounded (got ${#BIG_CTX})"
fi

echo "== sidecar file is left unchanged after the hook runs =="
setup_env
write_sidecar "SID-KEEP" "content that must survive untouched"
SIDECAR_KEEP="$(sidecar_path "SID-KEEP")"
SUM_BEFORE="$(shasum -a 256 "$SIDECAR_KEEP" | awk '{print $1}')"
start "SID-KEEP" "compact"
assert_eq "$RC" "0" "unchanged: exits 0"
if [ -e "$SIDECAR_KEEP" ]; then
  pass "unchanged: sidecar file still exists"
else
  fail "unchanged: sidecar file still exists (missing: $SIDECAR_KEEP)"
fi
SUM_AFTER="$(shasum -a 256 "$SIDECAR_KEEP" | awk '{print $1}')"
assert_eq "$SUM_AFTER" "$SUM_BEFORE" "unchanged: checksum matches before and after"

echo "== special characters round-trip exactly through additionalContext =="
setup_env
mkdir -p "$COMPACT_DIR"
SIDECAR_RT="$(sidecar_path "SID-RT")"
cat > "$SIDECAR_RT" <<'EOF'
He said "hello" and then \escaped\ things.
Second line with a backslash \\ and a quote ' and more.
Third line.
EOF
start "SID-RT" "compact"
assert_eq "$RC" "0" "round-trip: exits 0"
jq -r '.hookSpecificOutput.additionalContext // empty' "$WORK/out" > "$WORK/actual_context" 2>/dev/null
jq -n --rawfile content "$SIDECAR_RT" --arg header "$HEADER" '$header + "\n\n" + $content' \
  | jq -r '.' > "$WORK/expected_context"
if diff -q "$WORK/actual_context" "$WORK/expected_context" >/dev/null 2>&1; then
  pass "round-trip: additionalContext equals header + blank line + original sidecar content exactly"
else
  fail "round-trip: additionalContext equals header + blank line + original sidecar content exactly (diff: $(diff "$WORK/expected_context" "$WORK/actual_context" | head -5))"
fi

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

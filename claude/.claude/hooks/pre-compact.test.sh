#!/usr/bin/env bash
# Behavioral tests for pre-compact.sh (PreCompact hook).
#
# Contract: reads one JSON object on stdin (session_id, transcript_path, cwd,
#   hook_event_name "PreCompact", trigger "auto"|"manual", custom_instructions).
#   Runs a sibling script "compact-timeline.sh" (resolved relative to the
#   hook's own path, not PATH) with transcript_path as its single argument,
#   writing that script's stdout to
#   $HOME/.claude/run/compact/<session_id>.md (creating dirs as needed).
#   Then prints a plain-text (not JSON) instruction block to stdout and
#   exits 0. The hook must never block compaction: on any failure (missing
#   session_id/transcript_path, bad stdin, missing or failing
#   compact-timeline.sh) it still exits 0, never 2, and never invokes the
#   claude CLI.
#
# Stubbed env: HOME is a throwaway dir, a stub `claude` is first on PATH and
# any PATH dir holding the real `claude` is stripped. The script under test
# is copied into a throwaway hook directory alongside a stubbed
# compact-timeline.sh so the sidecar content is observable.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_SRC="$TEST_DIR/pre-compact.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pre-compact-test.XXXXXX")"
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

HOME_DIR=""; HOOK_DIR=""; BINDIR=""; CWD=""; RC=0; OUT=""; ERR=""

setup_env() {
  HOME_DIR="$(mktemp -d "$WORK/home.XXXXXX")"
  HOOK_DIR="$(mktemp -d "$WORK/hook.XXXXXX")"
  BINDIR="$HOME_DIR/bin"
  CWD="$HOME_DIR/proj"
  mkdir -p "$BINDIR" "$CWD" "$HOME_DIR/.claude"
  cp "$SCRIPT_SRC" "$HOOK_DIR/pre-compact.sh" 2>/dev/null
  chmod +x "$HOOK_DIR/pre-compact.sh" 2>/dev/null
  cat > "$BINDIR/claude" <<'STUB'
#!/usr/bin/env bash
echo "stub claude: pre-compact.sh must not invoke the claude CLI" >&2
exit 97
STUB
  chmod +x "$BINDIR/claude"
}

install_timeline_ok() {
  cat > "$HOOK_DIR/compact-timeline.sh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$1"
echo "STUB TIMELINE"
STUB
  chmod +x "$HOOK_DIR/compact-timeline.sh"
}

install_timeline_fail() {
  cat > "$HOOK_DIR/compact-timeline.sh" <<'STUB'
#!/usr/bin/env bash
echo "boom" >&2
exit 3
STUB
  chmod +x "$HOOK_DIR/compact-timeline.sh"
}

pc_json() {
  local sid="$1" transcript="$2" trig="$3"
  jq -cn --arg s "$sid" --arg t "$transcript" --arg c "$CWD" --arg tr "$trig" '
    {
      session_id: $s, transcript_path: $t, cwd: $c,
      hook_event_name: "PreCompact", trigger: $tr, custom_instructions: null
    }
  '
}

run_hook() {
  local input="$1"
  shift
  env "$@" HOME="$HOME_DIR" PATH="$BINDIR:$SAFE_PATH" bash "$HOOK_DIR/pre-compact.sh" <<< "$input" >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
  ERR="$(cat "$WORK/err")"
}

set_mtime_days_ago() {
  local file="$1" days="$2"
  : > "$file"
  local ts
  if ts="$(date -v-"${days}"d +%Y%m%d%H%M 2>/dev/null)"; then
    touch -t "$ts" "$file"
  else
    touch -d "$days days ago" "$file"
  fi
}

run_hook_empty_stdin() {
  HOME="$HOME_DIR" PATH="$BINDIR:$SAFE_PATH" bash "$HOOK_DIR/pre-compact.sh" </dev/null >"$WORK/out" 2>"$WORK/err"
  RC=$?
  OUT="$(cat "$WORK/out")"
  ERR="$(cat "$WORK/err")"
}

sidecar_path() {
  printf '%s' "$HOME_DIR/.claude/run/compact/$1.md"
}

compact_dir_empty() {
  local dir="$HOME_DIR/.claude/run/compact"
  [ ! -d "$dir" ] || [ -z "$(ls -A "$dir" 2>/dev/null)" ]
}

INSTRUCTION_LINES=(
  "## Compact Instructions (dotclaude)"
  "10. Direction changes:"
  "11. WIP state:"
  "12. Tests and checks run:"
  "13. Open questions:"
)
INSTRUCTION_PHRASES=(
  "Do not reproduce it"
  "verbatim and absolute"
)

assert_instruction_block() {
  local out="$1" label="$2"
  local line
  for line in "${INSTRUCTION_LINES[@]}"; do
    assert_contains "$out" "$line" "$label: stdout contains line [$line]"
  done
  for line in "${INSTRUCTION_PHRASES[@]}"; do
    assert_contains "$out" "$line" "$label: stdout contains phrase [$line]"
  done
}

echo "== valid input writes a sidecar and prints the instruction block =="
setup_env
install_timeline_ok
SID="SID-1"
TRANSCRIPT="$HOME_DIR/transcript-1.jsonl"
run_hook "$(pc_json "$SID" "$TRANSCRIPT" "auto")"
assert_eq "$RC" "0" "valid: exits 0"
SIDECAR="$(sidecar_path "$SID")"
if [ -f "$SIDECAR" ]; then
  pass "valid: sidecar file exists at \$HOME/.claude/run/compact/$SID.md"
else
  fail "valid: sidecar file exists at \$HOME/.claude/run/compact/$SID.md (missing: $SIDECAR)"
fi
SIDECAR_CONTENT="$(cat "$SIDECAR" 2>/dev/null)"
assert_contains "$SIDECAR_CONTENT" "STUB TIMELINE" "valid: sidecar contains STUB TIMELINE"
assert_contains "$SIDECAR_CONTENT" "$TRANSCRIPT" "valid: sidecar contains the transcript path passed to compact-timeline.sh"
assert_instruction_block "$OUT" "valid"
FIRST_NONEMPTY_LINE="$(printf '%s\n' "$OUT" | grep -m1 .)"
assert_eq "$FIRST_NONEMPTY_LINE" "## Compact Instructions (dotclaude)" \
  "valid: first non-empty stdout line is the instructions header"
case "$OUT" in
  '{'*) fail "valid: stdout does not start with { (got JSON-looking output)" ;;
  *) pass "valid: stdout does not start with {" ;;
esac
case "$OUT" in
  *"stub claude"*) fail "valid: stdout never mentions stub claude" ;;
  *) pass "valid: stdout never mentions stub claude" ;;
esac

echo "== missing session_id never blocks and writes nothing =="
setup_env
install_timeline_ok
run_hook "$(pc_json "" "$HOME_DIR/transcript-2.jsonl" "auto" | jq -c 'del(.session_id)')"
assert_eq "$RC" "0" "missing session_id: exits 0"
assert_empty "$OUT" "missing session_id: stdout empty"
if compact_dir_empty; then
  pass "missing session_id: no file written under \$HOME/.claude/run/compact"
else
  fail "missing session_id: no file written under \$HOME/.claude/run/compact (found contents)"
fi

echo "== missing transcript_path never blocks and writes nothing =="
setup_env
install_timeline_ok
run_hook "$(pc_json "SID-3" "" "auto" | jq -c 'del(.transcript_path)')"
assert_eq "$RC" "0" "missing transcript_path: exits 0"
assert_empty "$OUT" "missing transcript_path: stdout empty"
if compact_dir_empty; then
  pass "missing transcript_path: no file written under \$HOME/.claude/run/compact"
else
  fail "missing transcript_path: no file written under \$HOME/.claude/run/compact (found contents)"
fi

echo "== empty stdin never blocks =="
setup_env
install_timeline_ok
run_hook_empty_stdin
assert_eq "$RC" "0" "empty stdin: exits 0"
assert_empty "$OUT" "empty stdin: stdout empty"

echo "== compact-timeline.sh exits non-zero: still prints block, no sidecar, stderr noted =="
setup_env
install_timeline_fail
SID="SID-5"
run_hook "$(pc_json "$SID" "$HOME_DIR/transcript-5.jsonl" "auto")"
assert_eq "$RC" "0" "timeline failure: exits 0"
assert_instruction_block "$OUT" "timeline failure"
if [ -n "$ERR" ]; then
  pass "timeline failure: stderr is non-empty"
else
  fail "timeline failure: stderr is non-empty (got empty)"
fi
SIDECAR="$(sidecar_path "$SID")"
if [ ! -f "$SIDECAR" ]; then
  pass "timeline failure: no sidecar file written"
else
  fail "timeline failure: no sidecar file written (found: $SIDECAR)"
fi

echo "== compact-timeline.sh missing: still prints block, stderr noted =="
setup_env
SID="SID-6"
run_hook "$(pc_json "$SID" "$HOME_DIR/transcript-6.jsonl" "auto")"
assert_eq "$RC" "0" "missing sibling: exits 0"
assert_instruction_block "$OUT" "missing sibling"
if [ -n "$ERR" ]; then
  pass "missing sibling: stderr is non-empty"
else
  fail "missing sibling: stderr is non-empty (got empty)"
fi

echo "== trigger manual and auto both produce the instruction block =="
setup_env
install_timeline_ok
run_hook "$(pc_json "SID-7A" "$HOME_DIR/transcript-7a.jsonl" "manual")"
assert_eq "$RC" "0" "trigger manual: exits 0"
assert_instruction_block "$OUT" "trigger manual"
run_hook "$(pc_json "SID-7B" "$HOME_DIR/transcript-7b.jsonl" "auto")"
assert_eq "$RC" "0" "trigger auto: exits 0"
assert_instruction_block "$OUT" "trigger auto"

echo "== stdout never reveals the stub claude CLI =="
setup_env
install_timeline_ok
run_hook "$(pc_json "SID-8" "$HOME_DIR/transcript-8.jsonl" "auto")"
assert_eq "$RC" "0" "stub claude check: exits 0"
case "$OUT" in
  *"stub claude"*) fail "stub claude check: stdout does not contain stub claude" ;;
  *) pass "stub claude check: stdout does not contain stub claude" ;;
esac

echo "== prunes stale sidecars older than COMPACT_SIDECAR_MAX_AGE_DAYS, default 14 =="
setup_env
install_timeline_ok
COMPACT_DIR="$HOME_DIR/.claude/run/compact"
mkdir -p "$COMPACT_DIR/keep"
set_mtime_days_ago "$COMPACT_DIR/old-a.md" 20
set_mtime_days_ago "$COMPACT_DIR/old-b.md" 20
set_mtime_days_ago "$COMPACT_DIR/fresh.md" 2
set_mtime_days_ago "$COMPACT_DIR/keep/nested-old.md" 20
set_mtime_days_ago "$HOME_DIR/.claude/run/decoy-old.md" 20
SID="SID-9"
TRANSCRIPT="$HOME_DIR/transcript-9.jsonl"
run_hook "$(pc_json "$SID" "$TRANSCRIPT" "auto")"
assert_eq "$RC" "0" "prune default: exits 0"
assert_instruction_block "$OUT" "prune default"
SIDECAR="$(sidecar_path "$SID")"
if [ -f "$SIDECAR" ]; then
  pass "prune default: sidecar file exists at \$HOME/.claude/run/compact/$SID.md"
else
  fail "prune default: sidecar file exists at \$HOME/.claude/run/compact/$SID.md (missing: $SIDECAR)"
fi
if [ ! -e "$COMPACT_DIR/old-a.md" ]; then
  pass "prune default: old-a.md gone"
else
  fail "prune default: old-a.md gone (still present)"
fi
if [ ! -e "$COMPACT_DIR/old-b.md" ]; then
  pass "prune default: old-b.md gone"
else
  fail "prune default: old-b.md gone (still present)"
fi
if [ -e "$COMPACT_DIR/fresh.md" ]; then
  pass "prune default: fresh.md survives"
else
  fail "prune default: fresh.md survives (missing)"
fi
if [ -e "$COMPACT_DIR/keep/nested-old.md" ]; then
  pass "prune default: keep/nested-old.md survives (no recursion)"
else
  fail "prune default: keep/nested-old.md survives (no recursion) (missing)"
fi
if [ -e "$HOME_DIR/.claude/run/decoy-old.md" ]; then
  pass "prune default: decoy-old.md outside compact dir survives"
else
  fail "prune default: decoy-old.md outside compact dir survives (missing)"
fi

echo "== COMPACT_SIDECAR_MAX_AGE_DAYS=30 keeps 20-day-old sidecars =="
setup_env
install_timeline_ok
COMPACT_DIR="$HOME_DIR/.claude/run/compact"
mkdir -p "$COMPACT_DIR/keep"
set_mtime_days_ago "$COMPACT_DIR/old-a.md" 20
set_mtime_days_ago "$COMPACT_DIR/old-b.md" 20
set_mtime_days_ago "$COMPACT_DIR/fresh.md" 2
set_mtime_days_ago "$COMPACT_DIR/keep/nested-old.md" 20
set_mtime_days_ago "$HOME_DIR/.claude/run/decoy-old.md" 20
SID="SID-9B"
TRANSCRIPT="$HOME_DIR/transcript-9b.jsonl"
run_hook "$(pc_json "$SID" "$TRANSCRIPT" "auto")" "COMPACT_SIDECAR_MAX_AGE_DAYS=30"
assert_eq "$RC" "0" "prune max-age=30: exits 0"
if [ -e "$COMPACT_DIR/old-a.md" ]; then
  pass "prune max-age=30: old-a.md survives"
else
  fail "prune max-age=30: old-a.md survives (missing)"
fi
if [ -e "$COMPACT_DIR/old-b.md" ]; then
  pass "prune max-age=30: old-b.md survives"
else
  fail "prune max-age=30: old-b.md survives (missing)"
fi

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

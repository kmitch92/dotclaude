#!/usr/bin/env bash
# Behavioral tests for claude-tfork.sh split-direction argument.
#
# Drives the real script end to end inside a stubbed environment:
#   - HOME points at a throwaway dir holding a fake session record for pane %99.
#   - TMUX / TMUX_PANE are set so the script takes the tmux branch and finds it.
#   - A stub `tmux` (first on PATH) logs every invocation and fakes a pane id,
#     so we can inspect the exact split-window flags the script chose.
# Nothing here touches the real ~/.claude. The real jq is used (record is valid JSON).

set -uo pipefail

SCRIPT="/Users/kiel.mitchell/dotclaude/claude/.claude/bin/claude-tfork.sh"
SCRATCH="/private/tmp/claude-488525469/-Users-kiel-mitchell/c1827a9e-5998-40f9-baf3-28720e662b71/scratchpad"

WORK="$(mktemp -d "${SCRATCH}/tfork-test.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

pass_count=0
fail_count=0

pass() { printf '    ok   - %s\n' "$1"; pass_count=$((pass_count + 1)); }
fail() { printf '    FAIL - %s\n' "$1"; fail_count=$((fail_count + 1)); }

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
    fail "$msg (did not expect to contain: [$needle])"
  else
    pass "$msg"
  fi
}

assert_eq() {
  local actual="$1" expected="$2" msg="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$msg"
  else
    fail "$msg (expected [$expected], got [$actual])"
  fi
}

assert_ne() {
  local actual="$1" unexpected="$2" msg="$3"
  if [ "$actual" != "$unexpected" ]; then
    pass "$msg"
  else
    fail "$msg (expected value != [$unexpected], got [$actual])"
  fi
}

# Globals populated by run_fork.
# SPLIT_FLAGS isolates the direction flags (the segment between `split-window`
# and `-c <cwd>`) so characters inside the cwd path can never cause a false
# match when we assert on -h/-v/-b.
OUT=""; ERR=""; RC=0; LOG=""; SPLIT_LINE=""; SPLIT_FLAGS=""; CWD=""

# run_fork [script-args...] : execute the script under a fresh stubbed env.
run_fork() {
  local home; home="$(mktemp -d "$WORK/home.XXXXXX")"
  local bindir="$home/bin"
  local sessions="$home/.claude/run/sessions"
  local proj="$home/proj"
  local tmuxlog="$home/tmux.log"
  mkdir -p "$bindir" "$sessions" "$proj"
  CWD="$proj"

  printf '{"session_id":"SID-TEST","cwd":"%s"}\n' "$proj" > "$sessions/tmux-99"

  cat > "$bindir/tmux" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TMUX_STUB_LOG"
if [ "${1:-}" = "split-window" ]; then
  echo "%99"
fi
exit 0
STUB
  chmod +x "$bindir/tmux"

  local errfile="$home/stderr.log"
  OUT="$(HOME="$home" PATH="$bindir:$PATH" TMUX=1 TMUX_PANE=%99 \
         TMUX_STUB_LOG="$tmuxlog" bash "$SCRIPT" "$@" 2>"$errfile")"
  RC=$?
  ERR="$(cat "$errfile")"
  LOG="$(cat "$tmuxlog" 2>/dev/null || true)"
  SPLIT_LINE="$(grep '^split-window' "$tmuxlog" 2>/dev/null | head -n1 || true)"
  SPLIT_FLAGS=""
  if [ -n "$SPLIT_LINE" ]; then
    local before="${SPLIT_LINE%% -c *}"      # e.g. "split-window -h -b"
    SPLIT_FLAGS="${before#split-window}"       # e.g. " -h -b"
  fi
}

# Shared regression assertions for any valid split direction.
assert_common_valid() {
  local label="$1"
  assert_eq "$RC" "0" "$label: exits 0"
  assert_contains "$OUT" "FORK OK" "$label: stdout reports FORK OK"
  assert_contains "$SPLIT_LINE" "-c $CWD" "$label: split-window keeps -c <cwd>"
  assert_contains "$SPLIT_LINE" "-P -F #{pane_id}" "$label: split-window keeps -P -F '#{pane_id}'"
  assert_contains "$LOG" "send-keys" "$label: send-keys issued"
  assert_contains "$LOG" "claude --resume SID-TEST --fork-session" \
    "$label: send-keys resumes forked session"
}

echo "== no argument -> default right split (-h, no -v, no -b) =="
run_fork
assert_common_valid "no-arg"
assert_contains "$SPLIT_FLAGS" "-h" "no-arg: uses -h"
assert_not_contains "$SPLIT_FLAGS" "-v" "no-arg: no -v"
assert_not_contains "$SPLIT_FLAGS" "-b" "no-arg: no -b"

echo "== 'l' -> right split (same as default: -h, no -b) =="
run_fork l
assert_common_valid "l"
assert_contains "$SPLIT_FLAGS" "-h" "l: uses -h"
assert_not_contains "$SPLIT_FLAGS" "-v" "l: no -v"
assert_not_contains "$SPLIT_FLAGS" "-b" "l: no -b"

echo "== 'h' -> left split (-h -b) =="
run_fork h
assert_common_valid "h"
assert_contains "$SPLIT_FLAGS" "-h -b" "h: uses -h -b"
assert_not_contains "$SPLIT_FLAGS" "-v" "h: no -v"

echo "== 'j' -> below split (-v, no -b) =="
run_fork j
assert_common_valid "j"
assert_contains "$SPLIT_FLAGS" "-v" "j: uses -v"
assert_not_contains "$SPLIT_FLAGS" "-b" "j: no -b"

echo "== 'k' -> above split (-v -b) =="
run_fork k
assert_common_valid "k"
assert_contains "$SPLIT_FLAGS" "-v -b" "k: uses -v -b"

echo "== invalid direction 'x' -> reject, no split =="
run_fork x
assert_ne "$RC" "0" "invalid: exits non-zero"
assert_contains "$ERR" "FORK FAILED" "invalid: stderr line begins FORK FAILED"
assert_not_contains "$LOG" "split-window" "invalid: no split attempted"

echo "== uppercase 'L' -> reject (case-sensitive), never silent default right =="
run_fork L
assert_ne "$RC" "0" "uppercase-L: exits non-zero"
assert_contains "$ERR" "FORK FAILED" "uppercase-L: stderr line begins FORK FAILED"
assert_not_contains "$LOG" "split-window" "uppercase-L: no split attempted"

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

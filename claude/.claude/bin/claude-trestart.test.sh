#!/usr/bin/env bash
# Behavioral tests for claude-trestart.sh — restart the current Claude Code
# session IN PLACE (continue, not fork).
#
# Drives the real script end to end inside a fully stubbed environment:
#   - HOME points at a throwaway dir holding a fake session record.
#   - Session lookup reuses claude-tfork.sh's resolution order (pane / cwd / newest).
#   - tmux / osascript / pgrep / uname / kill / claude are all stubbed (PATH shadow,
#     plus `enable -n kill` via BASH_ENV so the child's kill builtin resolves to the
#     PATH stub) so NOTHING real is spawned and NO real process is ever signalled.
# Nothing here touches the real ~/.claude. The real jq is used (records are valid JSON).
#
# The script does not exist yet: every case is expected to FAIL (RED phase).

set -uo pipefail

SCRIPT="/Users/kiel.mitchell/dotclaude/claude/.claude/bin/claude-trestart.sh"
SCRATCH="/private/tmp/claude-488525469/-Users-kiel-mitchell-dotclaude/62bf746d-4b7e-41ae-b918-4aecc2d3d220/scratchpad"

WORK="$(mktemp -d "${SCRATCH}/trestart-test.XXXXXX")"
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

assert_matches() {
  local haystack="$1" regex="$2" msg="$3"
  if printf '%s' "$haystack" | grep -Eq -- "$regex"; then
    pass "$msg"
  else
    fail "$msg (expected to match: [$regex])"
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

# Poll a file until it contains needle (deferred/detached actions land late).
wait_for_contains() {
  local f="$1" needle="$2" max="${3:-30}" i=0
  while [ "$i" -lt "$max" ]; do
    [ -f "$f" ] && grep -qF -- "$needle" "$f" && return 0
    sleep 0.1; i=$((i + 1))
  done
  return 1
}

# Globals populated by setup_env / exec_script.
OUT=""; ERR=""; RC=0; WAITED=0; TIMEDOUT=0
TLOG=""; KLOG=""; OLOG=""
HOMEDIR=""; BINDIR=""; SESSIONS=""; PROJ=""
TMUXLOG=""; KILLLOG=""; OSALOG=""; BOOTSTRAP=""

# setup_env <with_record: yes|no>
setup_env() {
  local with_record="$1"
  HOMEDIR="$(mktemp -d "$WORK/home.XXXXXX")"
  BINDIR="$HOMEDIR/bin"
  SESSIONS="$HOMEDIR/.claude/run/sessions"
  PROJ="$HOMEDIR/proj"
  TMUXLOG="$HOMEDIR/tmux.log"
  KILLLOG="$HOMEDIR/kill.log"
  OSALOG="$HOMEDIR/osascript.log"
  BOOTSTRAP="$HOMEDIR/bootstrap.sh"
  mkdir -p "$BINDIR" "$PROJ"
  : > "$TMUXLOG"; : > "$KILLLOG"; : > "$OSALOG"

  if [ "$with_record" = "yes" ]; then
    mkdir -p "$SESSIONS"
    printf '{"session_id":"SID-TEST","cwd":"%s"}\n' "$PROJ" > "$SESSIONS/tmux-99"
  fi

  # Force the child's `kill` to resolve to our PATH stub (disable the builtin).
  printf 'enable -n kill 2>/dev/null || true\n' > "$BOOTSTRAP"

  cat > "$BINDIR/tmux" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TMUX_STUB_LOG"
[ "${1:-}" = "display-message" ] && printf '%s\n' "${TMUX_PANE:-%0}"
exit 0
STUB

  cat > "$BINDIR/kill" <<'STUB'
#!/usr/bin/env bash
printf 'kill %s\n' "$*" >> "$KILL_LOG"
exit 0
STUB

  cat > "$BINDIR/osascript" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$OSA_LOG"
exit 0
STUB

  # Force the macOS Terminal branch deterministically: uname=Darwin, iTerm not running.
  cat > "$BINDIR/uname" <<'STUB'
#!/usr/bin/env bash
printf 'Darwin\n'
exit 0
STUB

  cat > "$BINDIR/pgrep" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB

  # Guard: the resume command must never actually execute during tests.
  cat > "$BINDIR/claude" <<'STUB'
#!/usr/bin/env bash
printf 'CLAUDE-RAN %s\n' "$*" >> "$HOME/claude-ran.log"
exit 0
STUB

  chmod +x "$BINDIR"/*
}

# exec_script [extra VAR=VAL env for env(1)] : run the script backgrounded with a
# watchdog so a hung/absent implementation can never hang the suite.
exec_script() {
  local outfile="$HOMEDIR/out.log" errfile="$HOMEDIR/err.log"
  : > "$outfile"; : > "$errfile"
  ( env -u TMUX -u TMUX_PANE \
        HOME="$HOMEDIR" PATH="$BINDIR:$PATH" BASH_ENV="$BOOTSTRAP" \
        TMUX_STUB_LOG="$TMUXLOG" KILL_LOG="$KILLLOG" OSA_LOG="$OSALOG" \
        "$@" bash "$SCRIPT" >"$outfile" 2>"$errfile" ) &
  local pid=$!
  WAITED=0; TIMEDOUT=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 0.1; WAITED=$((WAITED + 1))
    if [ "$WAITED" -ge 50 ]; then kill "$pid" 2>/dev/null; TIMEDOUT=1; break; fi
  done
  wait "$pid" 2>/dev/null; RC=$?
  OUT="$(cat "$outfile")"; ERR="$(cat "$errfile")"
  TLOG="$(cat "$TMUXLOG" 2>/dev/null || true)"
  KLOG="$(cat "$KILLLOG" 2>/dev/null || true)"
  OLOG="$(cat "$OSALOG" 2>/dev/null || true)"
}

echo "== no tracked session -> RESTART FAILED, non-zero, no destructive action =="
setup_env no
exec_script
assert_ne "$RC" "0" "no-session: exits non-zero"
assert_contains "$ERR" "RESTART FAILED" "no-session: stderr line begins RESTART FAILED"
assert_not_contains "$OLOG" "claude --resume" "no-session: no new window launched"
assert_eq "$KLOG" "" "no-session: nothing killed"

echo "== tmux branch -> respawn-pane -k restarts same session in place (no fork) =="
setup_env yes
exec_script TMUX=1 TMUX_PANE=%99
wait_for_contains "$TMUXLOG" "respawn-pane" 30 || true
TLOG="$(cat "$TMUXLOG" 2>/dev/null || true)"
assert_eq "$RC" "0" "tmux: exits 0"
assert_contains "$OUT" "RESTART OK" "tmux: stdout reports RESTART OK"
assert_contains "$TLOG" "respawn-pane" "tmux: issues respawn-pane"
assert_contains "$TLOG" "-k" "tmux: respawn-pane passes -k"
assert_contains "$TLOG" "-c $PROJ" "tmux: respawn-pane runs in session cwd (-c <cwd>)"
assert_contains "$TLOG" "%99" "tmux: respawn-pane targets the current pane"
assert_contains "$TLOG" "claude --resume SID-TEST" "tmux: resume command continues the session"
assert_not_contains "$TLOG" "--fork-session" "tmux: does NOT fork (no --fork-session)"

echo "== tmux branch -> pane-kill is scheduled detached; script exits 0 promptly =="
setup_env yes
exec_script TMUX=1 TMUX_PANE=%99
assert_eq "$RC" "0" "tmux-detach: exits 0"
assert_eq "$TIMEDOUT" "0" "tmux-detach: did not hang (no synchronous pane-kill blocking)"
assert_matches "$WAITED" '^([0-9]|1[0-9])$' "tmux-detach: returns promptly (<2s)"
assert_contains "$OUT" "RESTART OK" "tmux-detach: success reported before pane dies"

echo "== non-tmux branch -> new window resumes session, then parent kill scheduled =="
setup_env yes
exec_script
wait_for_contains "$KILLLOG" "kill" 30 || true
KLOG="$(cat "$KILLLOG" 2>/dev/null || true)"
OLOG="$(cat "$OSALOG" 2>/dev/null || true)"
assert_eq "$RC" "0" "non-tmux: exits 0"
assert_contains "$OUT" "RESTART OK" "non-tmux: stdout reports RESTART OK"
assert_contains "$OLOG" "claude --resume SID-TEST" "non-tmux: new window resumes the session"
assert_not_contains "$OLOG" "--fork-session" "non-tmux: does NOT fork (no --fork-session)"
assert_matches "$KLOG" 'kill[[:space:]]+[0-9]+' "non-tmux: schedules kill of parent pid"

echo "== non-tmux branch -> parent kill is detached & safe; exits 0 promptly =="
setup_env yes
exec_script
assert_eq "$RC" "0" "non-tmux-safe: exits 0"
assert_eq "$TIMEDOUT" "0" "non-tmux-safe: did not hang (kill not synchronous)"
assert_matches "$WAITED" '^([0-9]|1[0-9])$' "non-tmux-safe: returns promptly (<2s)"
if wait_for_contains "$KILLLOG" "kill" 30; then
  pass "non-tmux-safe: kill captured by stub (no real signal sent)"
else
  fail "non-tmux-safe: kill captured by stub (no real signal sent)"
fi

echo "== unsupported OS -> RESTART FAILED, non-zero, nothing killed/spawned =="
setup_env yes
cat > "$BINDIR/uname" <<'STUB'
#!/usr/bin/env bash
printf 'Plan9\n'
exit 0
STUB
chmod +x "$BINDIR/uname"
exec_script
assert_ne "$RC" "0" "unsupported-os: exits non-zero"
assert_contains "$ERR" "RESTART FAILED" "unsupported-os: stderr reports RESTART FAILED"
assert_eq "$KLOG" "" "unsupported-os: nothing killed"
assert_not_contains "$OLOG" "claude --resume" "unsupported-os: no window launched"

echo "== malformed session record -> graceful non-zero failure, no partial restart =="
setup_env yes
printf '{ this is not valid json\n' > "$SESSIONS/tmux-99"
exec_script TMUX=1 TMUX_PANE=%99
assert_ne "$RC" "0" "malformed-json: exits non-zero"
assert_eq "$KLOG" "" "malformed-json: nothing killed"
assert_not_contains "$TLOG" "respawn-pane" "malformed-json: no pane respawn (no partial restart)"
assert_not_contains "$OLOG" "claude --resume" "malformed-json: no window launched"

echo "== cwd with spaces -> resume command & -c dir quoted intact (tmux) =="
setup_env yes
SPACED="$HOMEDIR/proj with spaces"
mkdir -p "$SPACED"
printf '{"session_id":"SID-TEST","cwd":"%s"}\n' "$SPACED" > "$SESSIONS/tmux-99"
exec_script TMUX=1 TMUX_PANE=%99
wait_for_contains "$TMUXLOG" "respawn-pane" 30 || true
TLOG="$(cat "$TMUXLOG" 2>/dev/null || true)"
assert_eq "$RC" "0" "spaced-cwd: exits 0"
assert_contains "$TLOG" "-c $SPACED" "spaced-cwd: respawn-pane -c keeps full spaced cwd"
assert_contains "$TLOG" "claude --resume SID-TEST" "spaced-cwd: resume command intact"

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

#!/usr/bin/env bash
# Behavioral tests for track-session.sh (SessionStart hook) co-tenancy additions.
#
# Verifies the written record now also carries `branch` and `pane`, WITHOUT
# regressing existing fields (session_id, cwd, updated) or the cwd-<sha1>
# fallback record. Driven end to end in a stubbed environment:
#   - HOME points at a throwaway dir; records land under .claude/run/sessions.
#   - TMUX_PANE=%99 so the record is keyed tmux-99 and pane == "%99".
#   - Stub `git` (first on PATH) answers `rev-parse --abbrev-ref HEAD` from
#     STUB_GIT_BRANCH so branch capture is deterministic.
#   - Claude Code hook JSON ({session_id,cwd}) is fed on stdin.
# Nothing here touches the real ~/.claude. The real jq is used.

set -uo pipefail

SCRIPT="/Users/kiel.mitchell/dotclaude/claude/.claude/hooks/track-session.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/track-session-test.XXXXXX")"
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

assert_file_present() {
  local f="$1" msg="$2"
  if [ -e "$f" ]; then pass "$msg"; else fail "$msg (file missing: $f)"; fi
}

assert_has_key() {
  local file="$1" key="$2" msg="$3"
  if jq -e --arg k "$key" 'has($k) and (.[$k] != null) and (.[$k] != "")' "$file" >/dev/null 2>&1; then
    pass "$msg"
  else
    fail "$msg (json missing/empty key [$key] in $file)"
  fi
}

# Globals populated by the harness.
HOME_DIR=""; BINDIR=""; SESSIONS=""; CWD=""; STUB_GIT_BRANCH=""; RC=0

setup_env() {
  HOME_DIR="$(mktemp -d "$WORK/home.XXXXXX")"
  BINDIR="$HOME_DIR/bin"
  SESSIONS="$HOME_DIR/.claude/run/sessions"
  CWD="$HOME_DIR/proj"
  mkdir -p "$BINDIR" "$CWD"
  STUB_GIT_BRANCH="feature-cowork"

  cat > "$BINDIR/git" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do
  if [ "$a" = "rev-parse" ]; then
    printf '%s\n' "${STUB_GIT_BRANCH:-main}"
    exit 0
  fi
done
exit 0
STUB
  chmod +x "$BINDIR/git"
}

# run_track <sid> <pane>  (feeds {session_id,cwd} on stdin)
run_track() {
  local sid="$1" pane="$2"
  export STUB_GIT_BRANCH
  printf '{"session_id":"%s","cwd":"%s"}\n' "$sid" "$CWD" \
    | HOME="$HOME_DIR" PATH="$BINDIR:$PATH" TMUX=1 TMUX_PANE="$pane" \
      bash "$SCRIPT"
  RC=$?
}

echo "== tmux record includes new branch field (live git branch) =="
setup_env
run_track "SID-TRK" "%99"
assert_eq "$RC" "0" "branch: hook exits 0"
assert_file_present "$SESSIONS/tmux-99" "branch: pane record written"
assert_has_key "$SESSIONS/tmux-99" "branch" "branch: record has branch key"
REC_BRANCH="$(jq -r '.branch // empty' "$SESSIONS/tmux-99" 2>/dev/null || true)"
assert_eq "$REC_BRANCH" "feature-cowork" "branch: matches live git branch"

echo "== tmux record includes new pane field (raw TMUX_PANE) =="
setup_env
run_track "SID-TRK" "%99"
assert_has_key "$SESSIONS/tmux-99" "pane" "pane: record has pane key"
REC_PANE="$(jq -r '.pane // empty' "$SESSIONS/tmux-99" 2>/dev/null || true)"
assert_eq "$REC_PANE" "%99" "pane: equals raw TMUX_PANE"

echo "== existing fields preserved (session_id, cwd, updated) =="
setup_env
run_track "SID-TRK" "%99"
REC_SID="$(jq -r '.session_id // empty' "$SESSIONS/tmux-99" 2>/dev/null || true)"
REC_CWD="$(jq -r '.cwd // empty' "$SESSIONS/tmux-99" 2>/dev/null || true)"
assert_eq "$REC_SID" "SID-TRK" "preserved: session_id"
assert_eq "$REC_CWD" "$CWD" "preserved: cwd"
assert_has_key "$SESSIONS/tmux-99" "updated" "preserved: updated present"

echo "== cwd-<sha1> fallback record still written w/ existing fields =="
setup_env
run_track "SID-TRK" "%99"
FALLBACK="$(ls "$SESSIONS"/cwd-* 2>/dev/null | head -n1 || true)"
assert_file_present "$FALLBACK" "fallback: cwd-<sha1> record written"
assert_has_key "$FALLBACK" "session_id" "fallback: has session_id"
assert_has_key "$FALLBACK" "cwd" "fallback: has cwd"
assert_has_key "$FALLBACK" "updated" "fallback: has updated"

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

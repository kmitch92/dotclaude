#!/usr/bin/env bash
# Behavioral tests for claude-cowork-notice.sh (UserPromptSubmit co-tenancy hook).
#
# Drives the real hook end to end inside a stubbed environment:
#   - HOME points at a throwaway dir holding fixture session records.
#   - TMUX / TMUX_PANE are set so the hook keys itself by pane %99.
#   - Stub `tmux` (first on PATH) answers `list-panes -a -F '#{pane_id}'` from
#     STUB_TMUX_PANES, so we control which panes are "live".
#   - Stub `git` (first on PATH) answers `rev-parse --abbrev-ref HEAD` from
#     STUB_GIT_BRANCH, so we control the hook's own branch.
#   - Claude Code hook JSON ({session_id,cwd}) is fed on stdin.
# Nothing here touches the real ~/.claude. The real jq is used (records are JSON).

set -uo pipefail

SCRIPT="/Users/kiel.mitchell/dotclaude/claude/.claude/hooks/claude-cowork-notice.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/cowork-test.XXXXXX")"
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

assert_contains_i() {
  local haystack="$1" needle="$2" msg="$3"
  if printf '%s' "$haystack" | grep -qiF -- "$needle"; then
    pass "$msg"
  else
    fail "$msg (expected to contain (ci): [$needle])"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if printf '%s' "$haystack" | grep -qiF -- "$needle"; then
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

assert_file_absent() {
  local f="$1" msg="$2"
  if [ ! -e "$f" ]; then pass "$msg"; else fail "$msg (file still exists: $f)"; fi
}

assert_file_present() {
  local f="$1" msg="$2"
  if [ -e "$f" ]; then pass "$msg"; else fail "$msg (file missing: $f)"; fi
}

# Empty stdout is allowed (means "no additional context"); non-empty MUST be JSON.
assert_valid_json_or_empty() {
  local out="$1" msg="$2"
  if [ -z "$out" ]; then
    pass "$msg (empty)"
  elif printf '%s' "$out" | jq . >/dev/null 2>&1; then
    pass "$msg"
  else
    fail "$msg (stdout is neither empty nor valid JSON: [$out])"
  fi
}

# Globals populated by the harness.
OUT=""; ERR=""; RC=0
HOME_DIR=""; BINDIR=""; SESSIONS=""; CWD=""; CWD_OTHER=""
STUB_TMUX_PANES=""; STUB_GIT_BRANCH=""
ADDCTX=""

# setup_env: fresh throwaway HOME with stub tmux + git on PATH. Callers then
# drop fixture records into $SESSIONS before invoking run_hook.
setup_env() {
  HOME_DIR="$(mktemp -d "$WORK/home.XXXXXX")"
  BINDIR="$HOME_DIR/bin"
  SESSIONS="$HOME_DIR/.claude/run/sessions"
  CWD="$HOME_DIR/proj"
  CWD_OTHER="$HOME_DIR/other"
  mkdir -p "$BINDIR" "$SESSIONS" "$CWD" "$CWD_OTHER"
  STUB_TMUX_PANES="%99"
  STUB_GIT_BRANCH="main"

  cat > "$BINDIR/tmux" <<'STUB'
#!/usr/bin/env bash
if [ "${1:-}" = "list-panes" ]; then
  for p in ${STUB_TMUX_PANES:-}; do printf '%s\n' "$p"; done
fi
exit 0
STUB
  chmod +x "$BINDIR/tmux"

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

# write_record <file> <sid> <cwd> <branch> <pane> <updated>
write_record() {
  jq -n --arg sid "$2" --arg cwd "$3" --arg branch "$4" --arg pane "$5" --arg updated "$6" \
    '{session_id:$sid, cwd:$cwd, branch:$branch, pane:$pane, updated:$updated}' > "$1"
}

# run_hook <sid> <pane>  (pane e.g. %99; feeds {session_id,cwd} on stdin)
run_hook() {
  local sid="$1" pane="$2"
  local errfile="$HOME_DIR/stderr.log"
  export STUB_TMUX_PANES STUB_GIT_BRANCH
  OUT="$(printf '{"session_id":"%s","cwd":"%s"}\n' "$sid" "$CWD" \
        | HOME="$HOME_DIR" PATH="$BINDIR:$PATH" TMUX=1 TMUX_PANE="$pane" \
          bash "$SCRIPT" 2>"$errfile")"
  RC=$?
  ERR="$(cat "$errfile" 2>/dev/null || true)"
  # additionalContext tolerant to either {additionalContext} or
  # {hookSpecificOutput:{additionalContext}} nesting.
  ADDCTX="$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // .additionalContext // empty' 2>/dev/null || true)"
}

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "== solo: only my own record for cwd+branch -> no warning =="
setup_env
write_record "$SESSIONS/tmux-99" "SID-SELF" "$CWD" "main" "%99" "$NOW"
run_hook "SID-SELF" "%99"
assert_eq "$RC" "0" "solo: exits 0"
assert_valid_json_or_empty "$OUT" "solo: stdout empty or valid JSON"
assert_not_contains "$OUT" "co-tenan" "solo: no co-tenancy warning"

echo "== one co-tenant: same cwd+branch, live pane -> warning w/ count 1 + pane id =="
setup_env
STUB_TMUX_PANES="%99 %50"
write_record "$SESSIONS/tmux-99" "SID-SELF"  "$CWD" "main" "%99" "$NOW"
write_record "$SESSIONS/tmux-50" "SID-OTHER" "$CWD" "main" "%50" "$NOW"
run_hook "SID-SELF" "%99"
assert_eq "$RC" "0" "one-cotenant: exits 0"
assert_valid_json_or_empty "$OUT" "one-cotenant: stdout valid JSON"
assert_ne "$ADDCTX" "" "one-cotenant: additionalContext present"
assert_contains_i "$ADDCTX" "co-tenan" "one-cotenant: context warns of co-tenancy"
assert_contains "$ADDCTX" "1" "one-cotenant: context states count 1"
assert_contains "$ADDCTX" "%50" "one-cotenant: context names co-tenant pane id"

echo "== same cwd, DIFFERENT branch -> not counted, no warning =="
setup_env
STUB_TMUX_PANES="%99 %55"
STUB_GIT_BRANCH="main"
write_record "$SESSIONS/tmux-99" "SID-SELF"  "$CWD" "main"      "%99" "$NOW"
write_record "$SESSIONS/tmux-55" "SID-OTHER" "$CWD" "feature-x" "%55" "$NOW"
run_hook "SID-SELF" "%99"
assert_eq "$RC" "0" "diff-branch: exits 0"
assert_valid_json_or_empty "$OUT" "diff-branch: stdout empty or valid JSON"
assert_not_contains "$OUT" "co-tenan" "diff-branch: no warning (branch differs)"

echo "== DIFFERENT cwd, same branch -> not counted, no warning =="
setup_env
STUB_TMUX_PANES="%99 %60"
write_record "$SESSIONS/tmux-99" "SID-SELF"  "$CWD"       "main" "%99" "$NOW"
write_record "$SESSIONS/tmux-60" "SID-OTHER" "$CWD_OTHER" "main" "%60" "$NOW"
run_hook "SID-SELF" "%99"
assert_eq "$RC" "0" "diff-cwd: exits 0"
assert_valid_json_or_empty "$OUT" "diff-cwd: stdout empty or valid JSON"
assert_not_contains "$OUT" "co-tenan" "diff-cwd: no warning (cwd differs)"

echo "== stale pane pruned: record for dead pane deleted, not counted =="
setup_env
STUB_TMUX_PANES="%99"   # %77 is NOT live
write_record "$SESSIONS/tmux-99" "SID-SELF"  "$CWD" "main" "%99" "$NOW"
write_record "$SESSIONS/tmux-77" "SID-DEAD"  "$CWD" "main" "%77" "$NOW"
run_hook "SID-SELF" "%99"
assert_eq "$RC" "0" "prune: exits 0"
assert_file_absent "$SESSIONS/tmux-77" "prune: dead pane record deleted"
assert_not_contains "$OUT" "co-tenan" "prune: dead pane not counted (no warning)"

echo "== self-exclusion: my own record never counts (solo stays solo) =="
setup_env
STUB_TMUX_PANES="%99"
write_record "$SESSIONS/tmux-99" "SID-SELF" "$CWD" "main" "%99" "$NOW"
run_hook "SID-SELF" "%99"
assert_eq "$RC" "0" "self-excl: exits 0"
assert_not_contains "$OUT" "co-tenan" "self-excl: own record not a co-tenant"

echo "== self-refresh: my record rewritten w/ branch + pane + fresh updated =="
setup_env
STUB_GIT_BRANCH="release-9"
# Pre-seed a stale record with a sentinel timestamp so refresh is observable.
write_record "$SESSIONS/tmux-99" "SID-SELF" "$CWD" "old-branch" "%99" "2000-01-01T00:00:00Z"
run_hook "SID-SELF" "%99"
assert_eq "$RC" "0" "refresh: exits 0"
assert_file_present "$SESSIONS/tmux-99" "refresh: own record exists"
REC_SID="$(jq -r '.session_id // empty' "$SESSIONS/tmux-99" 2>/dev/null || true)"
REC_BRANCH="$(jq -r '.branch // empty' "$SESSIONS/tmux-99" 2>/dev/null || true)"
REC_PANE="$(jq -r '.pane // empty' "$SESSIONS/tmux-99" 2>/dev/null || true)"
REC_UPDATED="$(jq -r '.updated // empty' "$SESSIONS/tmux-99" 2>/dev/null || true)"
assert_eq "$REC_SID" "SID-SELF" "refresh: record keeps session_id"
assert_eq "$REC_BRANCH" "release-9" "refresh: record has live branch"
assert_eq "$REC_PANE" "%99" "refresh: record has pane"
assert_ne "$REC_UPDATED" "2000-01-01T00:00:00Z" "refresh: updated timestamp refreshed"

echo "== malformed record present -> skipped gracefully, exit 0, no warning =="
setup_env
STUB_TMUX_PANES="%99 %42"
write_record "$SESSIONS/tmux-99" "SID-SELF" "$CWD" "main" "%99" "$NOW"
printf '{ this is not valid json ::' > "$SESSIONS/tmux-42"
run_hook "SID-SELF" "%99"
assert_eq "$RC" "0" "malformed: exits 0 (no crash)"
assert_valid_json_or_empty "$OUT" "malformed: stdout empty or valid JSON"
assert_not_contains "$OUT" "co-tenan" "malformed: unparseable record not counted"

echo "== two co-tenants: same cwd+branch, two live panes -> count 2 + BOTH pane ids =="
setup_env
STUB_TMUX_PANES="%99 %50 %51"
write_record "$SESSIONS/tmux-99" "SID-SELF"  "$CWD" "main" "%99" "$NOW"
write_record "$SESSIONS/tmux-50" "SID-A"     "$CWD" "main" "%50" "$NOW"
write_record "$SESSIONS/tmux-51" "SID-B"     "$CWD" "main" "%51" "$NOW"
run_hook "SID-SELF" "%99"
assert_eq "$RC" "0" "two-cotenant: exits 0"
assert_valid_json_or_empty "$OUT" "two-cotenant: stdout valid JSON"
assert_contains_i "$ADDCTX" "co-tenan" "two-cotenant: context warns of co-tenancy"
assert_contains "$ADDCTX" "2" "two-cotenant: context states count 2"
assert_contains "$ADDCTX" "%50" "two-cotenant: context names first co-tenant pane id"
assert_contains "$ADDCTX" "%51" "two-cotenant: context names second co-tenant pane id"

echo "== output shape parity: matches terse-reminder UserPromptSubmit envelope =="
setup_env
STUB_TMUX_PANES="%99 %50"
write_record "$SESSIONS/tmux-99" "SID-SELF"  "$CWD" "main" "%99" "$NOW"
write_record "$SESSIONS/tmux-50" "SID-OTHER" "$CWD" "main" "%50" "$NOW"
run_hook "SID-SELF" "%99"
TERSE_SCRIPT="/Users/kiel.mitchell/dotclaude/claude/.claude/bin/claude-terse-reminder.sh"
TERSE_OUT="$(bash "$TERSE_SCRIPT" </dev/null 2>/dev/null || true)"
COWORK_TOPKEYS="$(printf '%s' "$OUT" | jq -cS 'keys' 2>/dev/null || true)"
TERSE_TOPKEYS="$(printf '%s' "$TERSE_OUT" | jq -cS 'keys' 2>/dev/null || true)"
COWORK_SUBKEYS="$(printf '%s' "$OUT" | jq -cS '.hookSpecificOutput | keys' 2>/dev/null || true)"
TERSE_SUBKEYS="$(printf '%s' "$TERSE_OUT" | jq -cS '.hookSpecificOutput | keys' 2>/dev/null || true)"
COWORK_EVT="$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.hookEventName // empty' 2>/dev/null || true)"
assert_eq "$COWORK_TOPKEYS" "$TERSE_TOPKEYS" "shape-parity: top-level keys match terse-reminder"
assert_eq "$COWORK_SUBKEYS" "$TERSE_SUBKEYS" "shape-parity: hookSpecificOutput keys match terse-reminder"
assert_eq "$COWORK_EVT" "UserPromptSubmit" "shape-parity: hookEventName is UserPromptSubmit"

echo "== non-repo cwd: empty branch -> valid self record, exit 0, no crash =="
setup_env
cat > "$BINDIR/git" <<'STUB'
#!/usr/bin/env bash
# non-repo: rev-parse fails like git invoked outside a work tree
for a in "$@"; do
  if [ "$a" = "rev-parse" ]; then echo "fatal: not a git repository" >&2; exit 128; fi
done
exit 0
STUB
chmod +x "$BINDIR/git"
STUB_TMUX_PANES="%99"
run_hook "SID-SELF" "%99"
assert_eq "$RC" "0" "non-repo: exits 0"
assert_file_present "$SESSIONS/tmux-99" "non-repo: self record written"
NR_VALID="$(jq -e . "$SESSIONS/tmux-99" >/dev/null 2>&1 && echo yes || echo no)"
assert_eq "$NR_VALID" "yes" "non-repo: self record is valid JSON"
NR_BRANCH="$(jq -r '.branch // "SENTINEL"' "$SESSIONS/tmux-99" 2>/dev/null || true)"
assert_eq "$NR_BRANCH" "" "non-repo: self record branch is empty string"
assert_not_contains "$OUT" "co-tenan" "non-repo: solo non-repo session -> no warning"

echo "== non-repo: empty-branch co-tenant in DIFFERENT cwd not spuriously grouped =="
setup_env
cat > "$BINDIR/git" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do
  if [ "$a" = "rev-parse" ]; then echo "fatal: not a git repository" >&2; exit 128; fi
done
exit 0
STUB
chmod +x "$BINDIR/git"
STUB_TMUX_PANES="%99 %60"
write_record "$SESSIONS/tmux-60" "SID-A" "$CWD_OTHER" "" "%60" "$NOW"
run_hook "SID-SELF" "%99"
assert_eq "$RC" "0" "non-repo diff-cwd: exits 0"
assert_not_contains "$OUT" "co-tenan" "non-repo diff-cwd: empty-branch other cwd not grouped"

echo "== non-repo: empty-branch co-tenant in SAME cwd IS grouped (branch shown <none>) =="
setup_env
cat > "$BINDIR/git" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do
  if [ "$a" = "rev-parse" ]; then echo "fatal: not a git repository" >&2; exit 128; fi
done
exit 0
STUB
chmod +x "$BINDIR/git"
STUB_TMUX_PANES="%99 %61"
write_record "$SESSIONS/tmux-61" "SID-A" "$CWD" "" "%61" "$NOW"
run_hook "SID-SELF" "%99"
assert_eq "$RC" "0" "non-repo same-cwd: exits 0"
assert_contains_i "$ADDCTX" "co-tenan" "non-repo same-cwd: empty-branch same cwd grouped"
assert_contains "$ADDCTX" "%61" "non-repo same-cwd: names co-tenant pane id"
assert_contains "$ADDCTX" "<none>" "non-repo same-cwd: empty branch rendered as <none>"

echo "== prune-safety: empty/failed tmux snapshot must NOT delete live records =="
setup_env
STUB_TMUX_PANES=""   # tmux present but list-panes yields nothing (transient error)
write_record "$SESSIONS/tmux-99" "SID-SELF"  "$CWD" "main" "%99" "$NOW"
write_record "$SESSIONS/tmux-50" "SID-OTHER" "$CWD" "main" "%50" "$NOW"
run_hook "SID-SELF" "%99"
assert_eq "$RC" "0" "prune-safety: exits 0"
assert_file_present "$SESSIONS/tmux-50" "prune-safety: co-tenant live record survives empty snapshot"

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

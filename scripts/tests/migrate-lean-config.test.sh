#!/usr/bin/env bash
# Behavioral tests for migrate-lean-config.sh (one-off, idempotent switch-over of
# a machine to the lean config after rewrite/lean-config is merged and stowed).
#
# Contract:
#   - claude CLI missing: exit 1, "claude CLI not found", nothing else happens.
#   - $HOME/.claude/agents/worker.md missing: exit 1,
#     "merge rewrite/lean-config first", no claude calls, no file changes.
#   - claude plugin list; uninstall claude-mem@thedotmack once iff listed.
#   - claude mcp remove --scope user aws-core-mcp-server / aws-cdk-mcp-server
#     (non-zero exit ignored).
#   - <repo>/scripts/setup-mcp.sh run exactly once; failure -> exit 1,
#     "setup-mcp.sh failed", no "migration complete".
#   - $HOME/.mcp.json (file or symlink, not followed) moved to
#     $HOME/.mcp.json.bak.<timestamp>; absent -> no-op.
#   - $HOME/.claude/machine.json created as a byte-for-byte copy of
#     <repo>/claude/.claude/machine.template.json via scripts/setup-machine.sh when
#     missing; an existing file is left byte-for-byte unchanged.
#   - claude doctor: Auto-updates line containing "disabled" -> prints
#     "auto-updates disabled"; otherwise warns "auto-updates still enabled".
#   - success: exit 0, final line contains "migration complete".
#   - --dry-run: exit 0, names planned actions, only read-only claude calls,
#     setup-mcp.sh not run, no file changes.
#   - unknown argument: exit 1 with usage text.
#
# Stubbed env: each case runs a COPY of scripts/ in a throwaway repo dir whose
# scripts/setup-mcp.sh is replaced by a stub that logs each invocation and exits
# with a controllable code. The throwaway repo also gets a fixture template at
# claude/.claude/machine.template.json. HOME is a throwaway dir. A stub `claude`
# (first on PATH) logs each call as one JSON array line of its argv; `plugin list`
# and `doctor` print fixture files; `mcp remove` exits with a controllable code.
# Any PATH dir holding the real `claude` is stripped. The script is run from an
# unrelated cwd so it must locate the repo from its own path.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_REPO="$(cd "$TEST_DIR/../.." && pwd)"
TARGET_REL="scripts/migrate-lean-config.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/migrate-lean-config-test.XXXXXX")"
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

assert_ne() {
  local actual="$1" unexpected="$2" msg="$3"
  if [ "$actual" != "$unexpected" ]; then
    pass "$msg"
  else
    fail "$msg (expected value != [$unexpected], got [$actual])"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    pass "$msg"
  else
    fail "$msg (expected to contain: [$needle])"
  fi
}

assert_contains_ci() {
  local haystack="$1" needle="$2" msg="$3"
  if printf '%s' "$haystack" | grep -qiF -- "$needle"; then
    pass "$msg"
  else
    fail "$msg (expected to contain, case-insensitive: [$needle])"
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

assert_absent() {
  local f="$1" msg="$2"
  if [ ! -e "$f" ] && [ ! -L "$f" ]; then pass "$msg"; else fail "$msg (exists: $f)"; fi
}

assert_same_file() {
  local actual="$1" expected="$2" msg="$3"
  if [ -f "$actual" ] && [ ! -L "$actual" ] && cmp -s "$actual" "$expected"; then
    pass "$msg"
  else
    fail "$msg (missing, replaced, or content changed: $actual)"
  fi
}

if [ -f "$SRC_REPO/$TARGET_REL" ]; then
  pass "target: $TARGET_REL exists"
else
  fail "target: $TARGET_REL exists (missing: $SRC_REPO/$TARGET_REL)"
fi

JQ_BIN="$(command -v jq)"

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

PLUGINS_WITH_MEM='Installed plugins:

  > claude-mem@thedotmack
    Version: 6.5.0
    Scope: user
    Status: enabled

  > typescript-lsp@claude-plugins-official
    Version: 1.0.0
    Scope: user
    Status: enabled'

PLUGINS_WITHOUT_MEM='Installed plugins:

  > claude-mem@community
    Version: 0.1.0
    Scope: user
    Status: enabled

  > typescript-lsp@claude-plugins-official
    Version: 1.0.0
    Scope: user
    Status: enabled'

DOCTOR_DISABLED='Diagnostics
 L Currently running: native (2.1.0)
 L Path: /home/user/.local/bin/claude
 L Auto-updates: disabled (DISABLE_AUTOUPDATER set)
 L Search: OK (vendor)'

DOCTOR_ENABLED='Diagnostics
 L Currently running: native (2.1.0)
 L Path: /home/user/.local/bin/claude
 L Auto-updates: enabled
 L Telemetry: disabled
 L Search: OK (vendor)'

DOCTOR_NO_AUTOUPDATE_LINE='Diagnostics
 L Currently running: native (2.1.0)
 L Telemetry: disabled
 L Search: OK (vendor)'

HOME_DIR=""; REPO=""; BINDIR=""; RUN_CWD=""; CLAUDE_LOG=""; SETUP_LOG=""
PLUGIN_LIST_FILE=""; DOCTOR_FILE=""; RC=0; OUTPUT=""

write_claude_stub() {
  local remove_rc="$1"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'LOG=%q\nJQ=%q\nREMOVE_RC=%q\nPLUGIN_LIST_FILE=%q\nDOCTOR_FILE=%q\n' \
      "$CLAUDE_LOG" "$JQ_BIN" "$remove_rc" "$PLUGIN_LIST_FILE" "$DOCTOR_FILE"
    cat <<'STUB'
parts=()
for a in "$@"; do
  parts+=("$(printf '%s' "$a" | "$JQ" -Rs .)")
done
( IFS=,; printf '[%s]\n' "${parts[*]}" ) >> "$LOG"
case "${1:-} ${2:-}" in
  "plugin list") cat "$PLUGIN_LIST_FILE"; exit 0 ;;
  "plugin uninstall") exit 0 ;;
  "mcp remove") exit "$REMOVE_RC" ;;
esac
if [ "${1:-}" = "doctor" ]; then
  cat "$DOCTOR_FILE"
  exit 0
fi
exit 0
STUB
  } > "$BINDIR/claude"
  chmod +x "$BINDIR/claude"
}

write_setup_mcp_stub() {
  local setup_rc="$1"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'LOG=%q\nSETUP_RC=%q\n' "$SETUP_LOG" "$setup_rc"
    cat <<'STUB'
printf 'setup-mcp.sh invoked\n' >> "$LOG"
exit "$SETUP_RC"
STUB
  } > "$REPO/scripts/setup-mcp.sh"
  chmod +x "$REPO/scripts/setup-mcp.sh"
}

set_plugin_list() { printf '%s\n' "$1" > "$PLUGIN_LIST_FILE"; }
set_doctor() { printf '%s\n' "$1" > "$DOCTOR_FILE"; }

setup_env() {
  local with_claude="${1:-with-claude}" merged="${2:-merged}"
  HOME_DIR="$(mktemp -d "$WORK/home.XXXXXX")"
  REPO="$(mktemp -d "$WORK/repo.XXXXXX")"
  BINDIR="$(mktemp -d "$WORK/bin.XXXXXX")"
  RUN_CWD="$(mktemp -d "$WORK/cwd.XXXXXX")"
  local tag
  tag="$(basename "$BINDIR")"
  CLAUDE_LOG="$WORK/$tag.claude-calls.log"
  SETUP_LOG="$WORK/$tag.setup-mcp-calls.log"
  PLUGIN_LIST_FILE="$WORK/$tag.plugin-list.txt"
  DOCTOR_FILE="$WORK/$tag.doctor.txt"
  cp -R "$SRC_REPO/scripts" "$REPO/"
  mkdir -p "$REPO/claude/.claude"
  printf '{"workerCap": 2, "scoutCap": 6}\n' > "$REPO/claude/.claude/machine.template.json"
  write_setup_mcp_stub 0
  set_plugin_list "$PLUGINS_WITH_MEM"
  set_doctor "$DOCTOR_DISABLED"
  mkdir -p "$HOME_DIR/.claude"
  if [ "$merged" = "merged" ]; then
    mkdir -p "$HOME_DIR/.claude/agents"
    printf -- '---\nname: worker\n---\n' > "$HOME_DIR/.claude/agents/worker.md"
  fi
  if [ "$with_claude" = "with-claude" ]; then
    write_claude_stub 0
  fi
}

run_migrate() {
  ( cd "$RUN_CWD" && HOME="$HOME_DIR" PATH="$BINDIR:$SAFE_PATH" timeout 60 bash "$REPO/$TARGET_REL" "$@" ) </dev/null >"$WORK/output" 2>&1
  RC=$?
  OUTPUT="$(cat "$WORK/output")"
}

reset_logs() { rm -f "$CLAUDE_LOG" "$SETUP_LOG"; }

last_nonblank_line() { printf '%s\n' "$OUTPUT" | awk 'NF { l = $0 } END { print l }'; }

claude_call_count() {
  [ -f "$CLAUDE_LOG" ] || { echo 0; return 0; }
  "$JQ_BIN" -s 'length' "$CLAUDE_LOG"
}

exact_call_count() {
  [ -f "$CLAUDE_LOG" ] || { echo 0; return 0; }
  "$JQ_BIN" -s --argjson want "$1" '[.[] | select(. == $want)] | length' "$CLAUDE_LOG"
}

prefix_call_count() {
  [ -f "$CLAUDE_LOG" ] || { echo 0; return 0; }
  "$JQ_BIN" -s --argjson want "$1" '[.[] | select(.[0:($want | length)] == $want)] | length' "$CLAUDE_LOG"
}

non_readonly_calls() {
  [ -f "$CLAUDE_LOG" ] || return 0
  "$JQ_BIN" -c 'select((.[0:2] == ["plugin", "list"] or .[0:1] == ["doctor"]) | not)' "$CLAUDE_LOG"
}

setup_mcp_run_count() {
  [ -f "$SETUP_LOG" ] || { echo 0; return 0; }
  wc -l < "$SETUP_LOG" | tr -d ' '
}

backup_files() {
  local f
  for f in "$HOME_DIR"/.mcp.json.bak.?*; do
    if [ -e "$f" ] || [ -L "$f" ]; then printf '%s\n' "$f"; fi
  done
}

backup_count() { backup_files | grep -c . || true; }

UNINSTALL_MEM='["plugin","uninstall","claude-mem@thedotmack"]'
REMOVE_CORE='["mcp","remove","--scope","user","aws-core-mcp-server"]'
REMOVE_CDK='["mcp","remove","--scope","user","aws-cdk-mcp-server"]'

echo "== full migration on an unmigrated machine succeeds =="
setup_env
printf '{"mcpServers": {"legacy": {}}}\n' > "$HOME_DIR/.mcp.json"
cp "$HOME_DIR/.mcp.json" "$WORK/happy-mcp-json-before"
run_migrate
assert_eq "$RC" "0" "happy: exits 0"
assert_contains "$(last_nonblank_line)" "migration complete" "happy: final line says migration complete"
assert_ne "$(prefix_call_count '["plugin","list"]')" "0" "happy: claude plugin list called"
assert_eq "$(exact_call_count "$UNINSTALL_MEM")" "1" "happy: claude plugin uninstall claude-mem@thedotmack called exactly once"
assert_eq "$(exact_call_count "$REMOVE_CORE")" "1" "happy: claude mcp remove --scope user aws-core-mcp-server called"
assert_eq "$(exact_call_count "$REMOVE_CDK")" "1" "happy: claude mcp remove --scope user aws-cdk-mcp-server called"
assert_eq "$(setup_mcp_run_count)" "1" "happy: repo scripts/setup-mcp.sh run exactly once"
assert_ne "$(prefix_call_count '["doctor"]')" "0" "happy: claude doctor called"
assert_absent "$HOME_DIR/.mcp.json" "happy: \$HOME/.mcp.json moved away"
assert_eq "$(backup_count)" "1" "happy: exactly one \$HOME/.mcp.json.bak.<timestamp> created"
assert_eq "$("$JQ_BIN" -e '.workerCap == 2 and .scoutCap == 6' "$HOME_DIR/.claude/machine.json" 2>/dev/null || echo false)" "true" "happy: machine.json created with workerCap 2 and scoutCap 6"

echo "== claude-mem is uninstalled only after checking the plugin list =="
setup_env
run_migrate
ORDER_OK="$([ -f "$CLAUDE_LOG" ] && "$JQ_BIN" -s --argjson u "$UNINSTALL_MEM" '
  ([to_entries[] | select(.value[0:2] == ["plugin", "list"]) | .key] | first) as $l
  | ([to_entries[] | select(.value == $u) | .key] | first) as $x
  | ($l != null and $x != null and $l < $x)' "$CLAUDE_LOG" || echo false)"
assert_eq "$ORDER_OK" "true" "claude-mem order: plugin list precedes plugin uninstall"

echo "== claude-mem absent from plugin list: no uninstall =="
setup_env
set_plugin_list "$PLUGINS_WITHOUT_MEM"
run_migrate
assert_eq "$RC" "0" "no claude-mem: exits 0"
assert_ne "$(prefix_call_count '["plugin","list"]')" "0" "no claude-mem: claude plugin list called"
assert_eq "$(prefix_call_count '["plugin","uninstall"]')" "0" "no claude-mem: no plugin uninstall call (similarly named plugin ignored)"
assert_contains "$(last_nonblank_line)" "migration complete" "no claude-mem: final line says migration complete"

echo "== failing legacy mcp remove is ignored =="
setup_env
write_claude_stub 1
run_migrate
assert_eq "$RC" "0" "remove fails: exits 0"
assert_eq "$(exact_call_count "$REMOVE_CORE")" "1" "remove fails: aws-core-mcp-server remove attempted"
assert_eq "$(exact_call_count "$REMOVE_CDK")" "1" "remove fails: aws-cdk-mcp-server remove attempted"
assert_eq "$(setup_mcp_run_count)" "1" "remove fails: setup-mcp.sh still run"
assert_contains "$(last_nonblank_line)" "migration complete" "remove fails: final line says migration complete"

echo "== setup-mcp.sh failure fails the migration =="
setup_env
write_setup_mcp_stub 3
run_migrate
assert_eq "$RC" "1" "setup-mcp fails: exits 1"
assert_contains "$OUTPUT" "setup-mcp.sh failed" "setup-mcp fails: output says setup-mcp.sh failed"
assert_not_contains "$OUTPUT" "migration complete" "setup-mcp fails: does not report migration complete"
assert_eq "$(setup_mcp_run_count)" "1" "setup-mcp fails: setup-mcp.sh run exactly once"

echo "== legacy ~/.mcp.json regular file is backed up with content preserved =="
setup_env
printf '{"sentinel": "keep-me"}\n' > "$HOME_DIR/.mcp.json"
cp "$HOME_DIR/.mcp.json" "$WORK/file-mcp-json-before"
run_migrate
assert_eq "$RC" "0" "mcp.json file: exits 0"
assert_absent "$HOME_DIR/.mcp.json" "mcp.json file: original path gone"
assert_eq "$(backup_count)" "1" "mcp.json file: exactly one backup"
BAK="$(backup_files | head -n 1)"
assert_same_file "$BAK" "$WORK/file-mcp-json-before" "mcp.json file: backup is a regular file with identical content"

echo "== legacy ~/.mcp.json symlink is moved as a symlink, not followed =="
setup_env
LINK_TARGET="$WORK/$(basename "$HOME_DIR").linked-mcp.json"
printf '{"sentinel": "linked"}\n' > "$LINK_TARGET"
ln -s "$LINK_TARGET" "$HOME_DIR/.mcp.json"
run_migrate
assert_eq "$RC" "0" "mcp.json symlink: exits 0"
assert_absent "$HOME_DIR/.mcp.json" "mcp.json symlink: original path gone"
assert_eq "$(backup_count)" "1" "mcp.json symlink: exactly one backup"
BAK="$(backup_files | head -n 1)"
if [ -n "$BAK" ] && [ -L "$BAK" ]; then pass "mcp.json symlink: backup is itself a symlink"; else fail "mcp.json symlink: backup is itself a symlink (got [$BAK])"; fi
assert_eq "$(readlink "$BAK" 2>/dev/null || true)" "$LINK_TARGET" "mcp.json symlink: backup points at the original target"
assert_eq "$(cat "$LINK_TARGET")" '{"sentinel": "linked"}' "mcp.json symlink: target content unchanged"

echo "== dangling ~/.mcp.json symlink is still moved =="
setup_env
ln -s "$WORK/does-not-exist.json" "$HOME_DIR/.mcp.json"
run_migrate
assert_eq "$RC" "0" "mcp.json dangling: exits 0"
assert_absent "$HOME_DIR/.mcp.json" "mcp.json dangling: original path gone"
BAK="$(backup_files | head -n 1)"
assert_eq "$(readlink "$BAK" 2>/dev/null || true)" "$WORK/does-not-exist.json" "mcp.json dangling: backup symlink keeps its target"

echo "== absent ~/.mcp.json is a no-op =="
setup_env
run_migrate
assert_eq "$RC" "0" "no mcp.json: exits 0"
assert_absent "$HOME_DIR/.mcp.json" "no mcp.json: \$HOME/.mcp.json not created"
assert_eq "$(backup_count)" "0" "no mcp.json: no backup created"

echo "== existing machine.json is left byte-for-byte unchanged =="
setup_env
printf '{ "workerCap": 3,\n  "scoutCap": 1, "note": "hand-tuned" }\n' > "$HOME_DIR/.claude/machine.json"
cp "$HOME_DIR/.claude/machine.json" "$WORK/machine-json-before"
run_migrate
assert_eq "$RC" "0" "machine.json present: exits 0"
assert_same_file "$HOME_DIR/.claude/machine.json" "$WORK/machine-json-before" "machine.json present: byte-identical"

echo "== missing machine.json is created as valid JSON =="
setup_env
run_migrate
if "$JQ_BIN" -e . "$HOME_DIR/.claude/machine.json" >/dev/null 2>&1; then
  pass "machine.json missing: created file is valid JSON"
else
  fail "machine.json missing: created file is valid JSON"
fi
assert_eq "$("$JQ_BIN" '.workerCap' "$HOME_DIR/.claude/machine.json" 2>/dev/null || true)" "2" "machine.json missing: workerCap is the number 2"
assert_eq "$("$JQ_BIN" '.scoutCap' "$HOME_DIR/.claude/machine.json" 2>/dev/null || true)" "6" "machine.json missing: scoutCap is the number 6"

echo "== missing machine.json is a byte-for-byte copy of the repo template =="
setup_env
printf '{"workerCap": 5, "scoutCap": 3, "note": "fixture"}\n' > "$REPO/claude/.claude/machine.template.json"
run_migrate
assert_eq "$RC" "0" "template copy: exits 0"
assert_same_file "$HOME_DIR/.claude/machine.json" "$REPO/claude/.claude/machine.template.json" "template copy: machine.json is byte-identical to template"

echo "== missing template fails the migration =="
setup_env
rm -f "$REPO/claude/.claude/machine.template.json"
run_migrate
assert_ne "$RC" "0" "missing template: exits non-zero"
assert_absent "$HOME_DIR/.claude/machine.json" "missing template: machine.json absent"
assert_not_contains "$OUTPUT" "migration complete" "missing template: does not report migration complete"

echo "== doctor reports auto-updates disabled =="
setup_env
set_doctor "$DOCTOR_DISABLED"
run_migrate
assert_eq "$RC" "0" "doctor disabled: exits 0"
assert_contains "$OUTPUT" "auto-updates disabled" "doctor disabled: prints auto-updates disabled"
assert_not_contains "$OUTPUT" "auto-updates still enabled" "doctor disabled: no still-enabled warning"

echo "== doctor reports auto-updates enabled: warning, not failure =="
setup_env
set_doctor "$DOCTOR_ENABLED"
run_migrate
assert_eq "$RC" "0" "doctor enabled: exits 0"
assert_contains "$OUTPUT" "auto-updates still enabled" "doctor enabled: warns auto-updates still enabled"
assert_not_contains "$OUTPUT" "auto-updates disabled" "doctor enabled: 'disabled' on another line is not mistaken for auto-updates"
assert_contains "$(last_nonblank_line)" "migration complete" "doctor enabled: final line says migration complete"

echo "== doctor output without an Auto-updates line: warning, not failure =="
setup_env
set_doctor "$DOCTOR_NO_AUTOUPDATE_LINE"
run_migrate
assert_eq "$RC" "0" "doctor no line: exits 0"
assert_contains "$OUTPUT" "auto-updates still enabled" "doctor no line: warns auto-updates still enabled"
assert_contains "$(last_nonblank_line)" "migration complete" "doctor no line: final line says migration complete"

echo "== missing claude CLI fails and does nothing else =="
setup_env "without-claude"
printf '{"sentinel": "keep-me"}\n' > "$HOME_DIR/.mcp.json"
cp "$HOME_DIR/.mcp.json" "$WORK/noclaude-mcp-json-before"
run_migrate
assert_eq "$RC" "1" "no claude: exits 1"
assert_contains "$OUTPUT" "claude CLI not found" "no claude: output says claude CLI not found"
assert_eq "$(setup_mcp_run_count)" "0" "no claude: setup-mcp.sh not run"
assert_same_file "$HOME_DIR/.mcp.json" "$WORK/noclaude-mcp-json-before" "no claude: \$HOME/.mcp.json untouched"
assert_eq "$(backup_count)" "0" "no claude: no backup created"
assert_absent "$HOME_DIR/.claude/machine.json" "no claude: machine.json not created"
assert_not_contains "$OUTPUT" "migration complete" "no claude: does not report migration complete"

echo "== rewrite not merged (no ~/.claude/agents/worker.md) fails and does nothing =="
setup_env "with-claude" "unmerged"
printf '{"sentinel": "keep-me"}\n' > "$HOME_DIR/.mcp.json"
cp "$HOME_DIR/.mcp.json" "$WORK/unmerged-mcp-json-before"
run_migrate
assert_eq "$RC" "1" "unmerged: exits 1"
assert_contains "$OUTPUT" "merge rewrite/lean-config first" "unmerged: output says merge rewrite/lean-config first"
assert_eq "$(claude_call_count)" "0" "unmerged: no claude calls"
assert_eq "$(setup_mcp_run_count)" "0" "unmerged: setup-mcp.sh not run"
assert_same_file "$HOME_DIR/.mcp.json" "$WORK/unmerged-mcp-json-before" "unmerged: \$HOME/.mcp.json untouched"
assert_eq "$(backup_count)" "0" "unmerged: no backup created"
assert_absent "$HOME_DIR/.claude/machine.json" "unmerged: machine.json not created"
assert_not_contains "$OUTPUT" "migration complete" "unmerged: does not report migration complete"

echo "== stowed (symlinked) agents dir counts as merged =="
setup_env "with-claude" "unmerged"
STOWED_AGENTS="$WORK/$(basename "$HOME_DIR").stowed-agents"
mkdir -p "$STOWED_AGENTS"
printf -- '---\nname: worker\n---\n' > "$STOWED_AGENTS/worker.md"
rm -rf "$HOME_DIR/.claude/agents"
ln -s "$STOWED_AGENTS" "$HOME_DIR/.claude/agents"
run_migrate
assert_eq "$RC" "0" "stowed: exits 0"
assert_contains "$(last_nonblank_line)" "migration complete" "stowed: final line says migration complete"

echo "== --dry-run plans but changes nothing =="
setup_env
printf '{"sentinel": "keep-me"}\n' > "$HOME_DIR/.mcp.json"
cp "$HOME_DIR/.mcp.json" "$WORK/dryrun-mcp-json-before"
run_migrate --dry-run
assert_eq "$RC" "0" "dry-run: exits 0"
assert_eq "$(non_readonly_calls)" "" "dry-run: only read-only claude calls (plugin list, doctor)"
assert_eq "$(prefix_call_count '["plugin","uninstall"]')" "0" "dry-run: no plugin uninstall"
assert_eq "$(prefix_call_count '["mcp","remove"]')" "0" "dry-run: no mcp remove"
assert_eq "$(setup_mcp_run_count)" "0" "dry-run: setup-mcp.sh not run"
assert_same_file "$HOME_DIR/.mcp.json" "$WORK/dryrun-mcp-json-before" "dry-run: \$HOME/.mcp.json not moved"
assert_eq "$(backup_count)" "0" "dry-run: no backup created"
assert_absent "$HOME_DIR/.claude/machine.json" "dry-run: machine.json not written"
assert_contains "$OUTPUT" "claude-mem@thedotmack" "dry-run: plan names the claude-mem uninstall"
assert_contains "$OUTPUT" "aws-core-mcp-server" "dry-run: plan names the aws-core-mcp-server removal"
assert_contains "$OUTPUT" "aws-cdk-mcp-server" "dry-run: plan names the aws-cdk-mcp-server removal"
assert_contains "$OUTPUT" "setup-mcp.sh" "dry-run: plan names setup-mcp.sh"
assert_contains "$OUTPUT" ".mcp.json" "dry-run: plan names the ~/.mcp.json move"
assert_contains "$OUTPUT" "machine.json" "dry-run: plan names the machine.json write"

echo "== --dry-run leaves an existing machine.json unchanged =="
setup_env
printf '{"workerCap": 4, "scoutCap": 2}\n' > "$HOME_DIR/.claude/machine.json"
cp "$HOME_DIR/.claude/machine.json" "$WORK/dryrun-machine-json-before"
run_migrate --dry-run
assert_eq "$RC" "0" "dry-run machine.json: exits 0"
assert_same_file "$HOME_DIR/.claude/machine.json" "$WORK/dryrun-machine-json-before" "dry-run machine.json: byte-identical"

echo "== second run after a successful run is a no-op success =="
setup_env
printf '{"sentinel": "first-run"}\n' > "$HOME_DIR/.mcp.json"
run_migrate
assert_eq "$RC" "0" "idempotent: first run exits 0"
cp "$HOME_DIR/.claude/machine.json" "$WORK/idem-machine-json-after-first" 2>/dev/null || true
BACKUPS_AFTER_FIRST="$(backup_files)"
set_plugin_list "$PLUGINS_WITHOUT_MEM"
reset_logs
run_migrate
assert_eq "$RC" "0" "idempotent: second run exits 0"
assert_contains "$(last_nonblank_line)" "migration complete" "idempotent: second run final line says migration complete"
assert_eq "$(prefix_call_count '["plugin","uninstall"]')" "0" "idempotent: second run makes no uninstall call"
assert_eq "$(backup_files)" "$BACKUPS_AFTER_FIRST" "idempotent: second run creates no new backup"
assert_absent "$HOME_DIR/.mcp.json" "idempotent: \$HOME/.mcp.json still absent"
assert_same_file "$HOME_DIR/.claude/machine.json" "$WORK/idem-machine-json-after-first" "idempotent: machine.json unchanged by second run"

echo "== unknown argument fails with usage and changes nothing =="
setup_env
printf '{"sentinel": "keep-me"}\n' > "$HOME_DIR/.mcp.json"
cp "$HOME_DIR/.mcp.json" "$WORK/badarg-mcp-json-before"
run_migrate --bogus
assert_eq "$RC" "1" "unknown arg: exits 1"
assert_contains_ci "$OUTPUT" "usage" "unknown arg: prints usage text"
assert_eq "$(non_readonly_calls)" "" "unknown arg: no mutating claude calls"
assert_eq "$(setup_mcp_run_count)" "0" "unknown arg: setup-mcp.sh not run"
assert_same_file "$HOME_DIR/.mcp.json" "$WORK/badarg-mcp-json-before" "unknown arg: \$HOME/.mcp.json untouched"
assert_absent "$HOME_DIR/.claude/machine.json" "unknown arg: machine.json not created"

REAL_DATE_BIN="$(command -v date)"

write_frozen_date_stub() {
  {
    printf '#!/usr/bin/env bash\n'
    printf 'REAL_DATE=%q\n' "$REAL_DATE_BIN"
    cat <<'STUB'
if [ "$#" -eq 1 ] && [ "${1#+}" != "$1" ]; then
  printf '20260914091500\n'
  exit 0
fi
exec "$REAL_DATE" "$@"
STUB
  } > "$BINDIR/date"
  chmod +x "$BINDIR/date"
}

backup_contents_sorted() {
  local f
  backup_files | while IFS= read -r f; do cat "$f"; done | sort
}

echo "== runs within the same second never overwrite an existing backup =="
setup_env
write_frozen_date_stub
printf '{"sentinel": "run-1"}\n' > "$HOME_DIR/.mcp.json"
run_migrate
assert_eq "$RC" "0" "same second: first run exits 0"
FIRST_BAK="$(backup_files | head -n 1)"
cp "$FIRST_BAK" "$WORK/same-second-first-backup" 2>/dev/null || true
printf '{"sentinel": "run-2"}\n' > "$HOME_DIR/.mcp.json"
reset_logs
run_migrate
assert_eq "$RC" "0" "same second: second run exits 0"
printf '{"sentinel": "run-3"}\n' > "$HOME_DIR/.mcp.json"
reset_logs
run_migrate
assert_eq "$RC" "0" "same second: third run exits 0"
assert_absent "$HOME_DIR/.mcp.json" "same second: \$HOME/.mcp.json moved away"
assert_eq "$(backup_count)" "3" "same second: three distinct backups exist"
assert_same_file "$FIRST_BAK" "$WORK/same-second-first-backup" "same second: first backup byte-identical after later runs"
assert_eq "$(backup_contents_sorted)" "$(printf '%s\n' '{"sentinel": "run-1"}' '{"sentinel": "run-2"}' '{"sentinel": "run-3"}' | sort)" "same second: every run's ~/.mcp.json content preserved exactly once"

echo "== setup-mcp.sh failure never loses ~/.mcp.json =="
setup_env
write_setup_mcp_stub 3
printf '{"sentinel": "survive-setup-failure"}\n' > "$HOME_DIR/.mcp.json"
cp "$HOME_DIR/.mcp.json" "$WORK/setupfail-mcp-json-before"
run_migrate
assert_eq "$RC" "1" "setup-mcp fails with mcp.json: exits 1"
if [ -e "$HOME_DIR/.mcp.json" ] || [ -L "$HOME_DIR/.mcp.json" ]; then
  assert_same_file "$HOME_DIR/.mcp.json" "$WORK/setupfail-mcp-json-before" "setup-mcp fails with mcp.json: left in place byte-identical"
  assert_eq "$(backup_count)" "0" "setup-mcp fails with mcp.json: left in place, so no backup"
else
  assert_eq "$(backup_count)" "1" "setup-mcp fails with mcp.json: moved to exactly one backup"
  assert_same_file "$(backup_files | head -n 1)" "$WORK/setupfail-mcp-json-before" "setup-mcp fails with mcp.json: backup byte-identical"
fi

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

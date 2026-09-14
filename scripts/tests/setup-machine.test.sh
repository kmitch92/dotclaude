#!/usr/bin/env bash
# Behavioral tests for setup-machine.sh (initializes $HOME/.claude/machine.json from template).
#
# Contract: bash <repo>/scripts/setup-machine.sh (no arguments). Repo = parent of
# the script's own dir; template = <repo>/claude/.claude/machine.template.json;
# target = $HOME/.claude/machine.json.
# - target absent (neither file nor symlink): copy template byte-for-byte to target;
#   exit 0; output contains "Created".
# - target exists as file, or as symlink (including dangling): replaced by a
#   regular file, byte-for-byte copy of the template; a symlink is not followed
#   (its destination is untouched); exit 0; output contains "Updated".
# - template missing: exit non-zero; output contains "machine.template.json not found";
#   target not created.
# - template not valid JSON (per jq): exit non-zero; output contains "not valid JSON";
#   target not created.
# - jq not on PATH: exit non-zero; output contains "jq not found"; target not created.
# - $HOME/.claude directory missing: exit non-zero; output contains
#   "<HOME>/.claude not found" rendered with the real HOME path;
#   nothing created.
# - template edited after a run: rerun exits 0 and target matches the new
#   template.
#
# Stubbed env: each case runs a COPY of scripts/ in a throwaway repo dir with a
# fixture template at <throwaway repo>/claude/.claude/machine.template.json.
# HOME is a throwaway dir with .claude/ created (except in the missing-dir case).
# The script is run from an unrelated cwd so it must locate the repo from its own
# path. Real jq and external tools are used; a test-restricted PATH is built only
# for the jq-missing case.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_REPO="$(cd "$TEST_DIR/../.." && pwd)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/setup-machine-test.XXXXXX")"
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

JQ_BIN="$(command -v jq)"
BASH_BIN="$(command -v bash)"
TIMEOUT_BIN="$(command -v timeout)"

HOME_DIR=""; REPO=""; RUN_CWD=""; RC=0; OUTPUT=""

setup_env() {
  HOME_DIR="$(mktemp -d "$WORK/home.XXXXXX")"
  mkdir -p "$HOME_DIR/.claude"
  REPO="$(mktemp -d "$WORK/repo.XXXXXX")"
  RUN_CWD="$(mktemp -d "$WORK/cwd.XXXXXX")"
  cp -R "$SRC_REPO/scripts" "$REPO/"
  mkdir -p "$REPO/claude/.claude"
}

setup_env_no_dotclaude() {
  HOME_DIR="$(mktemp -d "$WORK/home.XXXXXX")"
  # Do not create $HOME_DIR/.claude
  REPO="$(mktemp -d "$WORK/repo.XXXXXX")"
  RUN_CWD="$(mktemp -d "$WORK/cwd.XXXXXX")"
  cp -R "$SRC_REPO/scripts" "$REPO/"
  mkdir -p "$REPO/claude/.claude"
}

write_template() {
  local content="$1"
  printf '%s' "$content" > "$REPO/claude/.claude/machine.template.json"
}

run_setup() {
  ( cd "$RUN_CWD" && HOME="$HOME_DIR" "$TIMEOUT_BIN" 120 "$BASH_BIN" "$REPO/scripts/setup-machine.sh" </dev/null >"$WORK/output" 2>&1 )
  RC=$?
  OUTPUT="$(cat "$WORK/output")"
}

run_setup_with_path() {
  local custom_path="$1"
  ( cd "$RUN_CWD" && HOME="$HOME_DIR" PATH="$custom_path" "$TIMEOUT_BIN" 120 "$BASH_BIN" "$REPO/scripts/setup-machine.sh" </dev/null >"$WORK/output" 2>&1 )
  RC=$?
  OUTPUT="$(cat "$WORK/output")"
}

echo "== target script exists in real repo =="
assert_eq "1" "$([ -x "$SRC_REPO/scripts/setup-machine.sh" ] && echo 1 || echo 0)" "setup-machine.sh exists and is executable"

echo "== real repo template is valid =="
assert_eq "1" "$([ -f "$SRC_REPO/claude/.claude/machine.template.json" ] && echo 1 || echo 0)" "machine.template.json exists"
REAL_TEMPLATE_VALID="$([ -f "$SRC_REPO/claude/.claude/machine.template.json" ] && "$JQ_BIN" -e . <"$SRC_REPO/claude/.claude/machine.template.json" >/dev/null 2>&1 && echo 1 || echo 0)"
assert_eq "$REAL_TEMPLATE_VALID" "1" "machine.template.json is valid JSON"
REAL_WORKER_CAP="$("$JQ_BIN" -r '.workerCap' <"$SRC_REPO/claude/.claude/machine.template.json" 2>/dev/null || echo "")"
assert_eq "$REAL_WORKER_CAP" "5" "machine.template.json has workerCap=5"
REAL_SCOUT_CAP="$("$JQ_BIN" -r '.scoutCap' <"$SRC_REPO/claude/.claude/machine.template.json" 2>/dev/null || echo "")"
assert_eq "$REAL_SCOUT_CAP" "10" "machine.template.json has scoutCap=10"

echo "== target absent: copy template and exit 0 =="
setup_env
write_template '{"workerCap": 5, "scoutCap": 3}
'
run_setup
assert_eq "$RC" "0" "copy: exits 0"
assert_contains "$OUTPUT" "Created" "copy: output contains Created"
if [ -f "$HOME_DIR/.claude/machine.json" ]; then
  if cmp -s "$REPO/claude/.claude/machine.template.json" "$HOME_DIR/.claude/machine.json"; then
    pass "copy: target is byte-identical to template"
  else
    fail "copy: target is byte-identical to template (content differs)"
  fi
else
  fail "copy: target is byte-identical to template (target does not exist)"
fi

echo "== target is an existing file: overwrite with template =="
setup_env
write_template '{"workerCap": 5, "scoutCap": 3}
'
printf '{"original": "old-values"}\n' > "$HOME_DIR/.claude/machine.json"
run_setup
assert_eq "$RC" "0" "file: exits 0"
assert_contains "$OUTPUT" "Updated" "file: output contains Updated"
if cmp -s "$HOME_DIR/.claude/machine.json" "$REPO/claude/.claude/machine.template.json"; then
  pass "file: target is byte-identical to template"
else
  fail "file: target is byte-identical to template (content differs)"
fi

echo "== target is a symlink: replaced by a regular file, destination untouched =="
setup_env
write_template '{"workerCap": 5, "scoutCap": 3}
'
LINK_TARGET="$WORK/$(basename "$HOME_DIR").linked-machine.json"
printf '{"linked": "keep-me"}\n' > "$LINK_TARGET"
ln -s "$LINK_TARGET" "$HOME_DIR/.claude/machine.json"
cp "$LINK_TARGET" "$WORK/link-target-before"
run_setup
assert_eq "$RC" "0" "symlink: exits 0"
assert_contains "$OUTPUT" "Updated" "symlink: output contains Updated"
assert_eq "$([ -f "$HOME_DIR/.claude/machine.json" ] && [ ! -L "$HOME_DIR/.claude/machine.json" ] && echo 1 || echo 0)" "1" "symlink: target is now a regular file"
if cmp -s "$HOME_DIR/.claude/machine.json" "$REPO/claude/.claude/machine.template.json"; then
  pass "symlink: target is byte-identical to template"
else
  fail "symlink: target is byte-identical to template (content differs)"
fi
if cmp -s "$LINK_TARGET" "$WORK/link-target-before"; then
  pass "symlink: old symlink destination content unchanged"
else
  fail "symlink: old symlink destination content unchanged (changed)"
fi

echo "== target is a dangling symlink: replaced by a regular file =="
setup_env
write_template '{"workerCap": 5, "scoutCap": 3}
'
DANGLING_TARGET="$WORK/nonexistent-target"
ln -s "$DANGLING_TARGET" "$HOME_DIR/.claude/machine.json"
run_setup
assert_eq "$RC" "0" "dangling: exits 0"
assert_contains "$OUTPUT" "Updated" "dangling: output contains Updated"
assert_eq "$([ -f "$HOME_DIR/.claude/machine.json" ] && [ ! -L "$HOME_DIR/.claude/machine.json" ] && echo 1 || echo 0)" "1" "dangling: target is now a regular file"
if cmp -s "$HOME_DIR/.claude/machine.json" "$REPO/claude/.claude/machine.template.json"; then
  pass "dangling: target is byte-identical to template"
else
  fail "dangling: target is byte-identical to template (content differs)"
fi
assert_absent "$DANGLING_TARGET" "dangling: old symlink destination still does not exist"

echo "== template missing: exit non-zero, output message, do not create target =="
setup_env
run_setup
assert_ne "$RC" "0" "missing-template: exits non-zero"
assert_contains "$OUTPUT" "machine.template.json not found" "missing-template: output contains machine.template.json not found"
assert_absent "$HOME_DIR/.claude/machine.json" "missing-template: target not created"

echo "== template not valid JSON: exit non-zero, output message, do not create target =="
setup_env
write_template '{"broken": json}'
run_setup
assert_ne "$RC" "0" "invalid-json: exits non-zero"
assert_contains "$OUTPUT" "not valid JSON" "invalid-json: output contains not valid JSON"
assert_absent "$HOME_DIR/.claude/machine.json" "invalid-json: target not created"

echo "== jq not on PATH: exit non-zero, output message, do not create target =="
setup_env
write_template '{"workerCap": 5, "scoutCap": 3}
'
TOOLDIR="$(mktemp -d "$WORK/tools.XXXXXX")"
for tool in bash cp cat dirname mkdir printf rm ln tput uname; do
  ln -s "$(command -v "$tool")" "$TOOLDIR/$tool" 2>/dev/null || true
done
if PATH="$TOOLDIR" command -v jq >/dev/null 2>&1; then
  fail "jq-missing: PATH still has jq (cannot test this case)"
else
  run_setup_with_path "$TOOLDIR"
  assert_ne "$RC" "0" "jq-missing: exits non-zero"
  assert_contains "$OUTPUT" "jq not found" "jq-missing: output contains jq not found"
  assert_absent "$HOME_DIR/.claude/machine.json" "jq-missing: target not created"
fi

echo "== $HOME/.claude directory missing: exit non-zero, output message, do not create =="
setup_env_no_dotclaude
write_template '{"workerCap": 5, "scoutCap": 3}
'
run_setup
assert_ne "$RC" "0" "missing-dir: exits non-zero"
assert_contains "$OUTPUT" "$HOME_DIR/.claude not found" "missing-dir: output contains HOME/.claude not found with real path"
assert_absent "$HOME_DIR/.claude/machine.json" "missing-dir: target not created"
assert_absent "$HOME_DIR/.claude" "missing-dir: .claude directory not created"

echo "== template edited after a run: rerun applies the new template =="
setup_env
write_template '{"workerCap": 5, "scoutCap": 3}
'
run_setup
assert_eq "$RC" "0" "toggle: first run exits 0"
write_template '{"workerCap": 1, "scoutCap": 9}
'
run_setup
assert_eq "$RC" "0" "toggle: second run exits 0"
assert_contains "$OUTPUT" "Updated" "toggle: second run output contains Updated"
if cmp -s "$HOME_DIR/.claude/machine.json" "$REPO/claude/.claude/machine.template.json"; then
  pass "toggle: target matches the edited template"
else
  fail "toggle: target matches the edited template (content differs)"
fi

echo "== script can be run from unrelated cwd =="
setup_env
write_template '{"workerCap": 5, "scoutCap": 3}
'
( cd "$RUN_CWD" && HOME="$HOME_DIR" "$TIMEOUT_BIN" 120 "$BASH_BIN" "$REPO/scripts/setup-machine.sh" </dev/null >"$WORK/output" 2>&1 )
RC=$?
OUTPUT="$(cat "$WORK/output")"
assert_eq "$RC" "0" "unrelated-cwd: exits 0"
assert_contains "$OUTPUT" "Created" "unrelated-cwd: output contains Created"
assert_eq "1" "$([ -f "$HOME_DIR/.claude/machine.json" ] && echo 1 || echo 0)" "unrelated-cwd: target created"

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

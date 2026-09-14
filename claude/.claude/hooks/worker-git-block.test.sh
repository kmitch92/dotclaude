#!/usr/bin/env bash
# Behavioral tests for worker-git-block.sh (PreToolUse[Bash] hook in the worker
# agent file).
#
# Contract: workers may not commit, push, rebase or hard-reset. Such Bash
# commands are blocked with exit 2 and a stderr reason naming the operation;
# read-only git, staging, unstaging and non-git commands are allowed (exit 0).
# Non-Bash tools and invalid stdin are allowed (the hook never blocks on its own
# failure).
# Stubbed env: HOME is a throwaway dir, a stub `claude` is first on PATH and any
# PATH dir holding the real `claude` is stripped. The hook is fed hook JSON on
# stdin; it must never execute the command itself. The real jq is used.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$TEST_DIR/worker-git-block.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/worker-git-block-test.XXXXXX")"
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

assert_matches_i() {
  local haystack="$1" pattern="$2" msg="$3"
  if printf '%s' "$haystack" | grep -qiE -- "$pattern"; then
    pass "$msg"
  else
    fail "$msg (expected to match (ci): [$pattern], got [$haystack])"
  fi
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

HOME_DIR="$(mktemp -d "$WORK/home.XXXXXX")"
BINDIR="$HOME_DIR/bin"
CWD="$HOME_DIR/proj"
mkdir -p "$BINDIR" "$CWD"
cat > "$BINDIR/claude" <<'STUB'
#!/usr/bin/env bash
echo "stub claude: worker-git-block.sh must not invoke the claude CLI" >&2
exit 97
STUB
chmod +x "$BINDIR/claude"

RC=0; OUT=""; ERR=""

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
}

tool_json() {
  local tool="$1" cmd="$2"
  jq -cn --arg t "$tool" --arg c "$cmd" --arg d "$CWD" '{
    session_id: "SID-GIT", cwd: $d, hook_event_name: "PreToolUse",
    tool_name: $t, tool_use_id: "toolu_git_1",
    tool_input: {command: $c, description: "run command"}
  }'
}

expect_blocked() {
  local cmd="$1" op="$2"
  run_hook "$(tool_json "Bash" "$cmd")"
  assert_eq "$RC" "2" "blocked [$cmd]: exits 2"
  assert_contains "$ERR" "$op" "blocked [$cmd]: stderr names the operation ($op)"
  assert_matches_i "$ERR" "(^|[^/[:alnum:]])workers?([^-[:alnum:]]|$)" "blocked [$cmd]: stderr says it is a worker restriction"
  assert_matches_i "$ERR" "not|n't" "blocked [$cmd]: stderr says workers may not run it"
}

expect_allowed() {
  local cmd="$1"
  run_hook "$(tool_json "Bash" "$cmd")"
  assert_eq "$RC" "0" "allowed [$cmd]: exits 0"
}

echo "== hook script is present and executable (registered by path) =="
if [ -x "$SCRIPT" ]; then
  pass "script exists and is executable"
else
  fail "script exists and is executable (missing or not executable: $SCRIPT)"
fi

echo "== history-changing git operations are blocked =="
expect_blocked "git commit -m x" "commit"
expect_blocked "git commit --amend" "commit"
expect_blocked "git push" "push"
expect_blocked "git push --force origin main" "push"
expect_blocked "git rebase main" "rebase"
expect_blocked "git reset --hard HEAD~1" "reset"

echo "== blocked operations are caught behind -C and compound commands =="
expect_blocked "git -C /tmp/x commit -m y" "commit"
expect_blocked "cd /tmp/x && git commit -m y" "commit"
expect_blocked "npm test; git push" "push"

echo "== blocked operations are caught regardless of spacing and separators =="
expect_blocked "git   commit -m x" "commit"
expect_blocked $'git\tcommit -m x' "commit"
expect_blocked "  git push" "push"
expect_blocked "true&&git commit -m x" "commit"
expect_blocked "npm test;git push" "push"
expect_blocked "false||git push" "push"
expect_blocked $'npm test\ngit push' "push"

echo "== blocked operations are caught behind global options, full paths and trailing flags =="
expect_blocked "git -c user.name=x commit -m y" "commit"
expect_blocked "/usr/bin/git push" "push"
expect_blocked "git reset HEAD~1 --hard" "reset"
expect_blocked 'git -C "/tmp/my dir" commit -m y' "commit"
expect_blocked 'git -C /tmp/my\ dir commit -m y' "commit"

echo "== read-only, staging and non-git commands are allowed =="
expect_allowed "git status"
expect_allowed "git diff"
expect_allowed "git log --oneline"
expect_allowed "git add /abs/file.ts"
expect_allowed "git reset /abs/file.ts"
expect_allowed "npx vitest run /abs/a.test.ts"

echo "== an escaped space keeps a history-changing word inside its argument =="
expect_allowed 'git -C /tmp/my\ commit status'
expect_allowed 'git log --grep=commit\ fix'

echo "== a git operation mentioned only inside a quoted string is allowed =="
expect_allowed 'echo "git commit is blocked"'

echo "== tools other than Bash are allowed =="
run_hook "$(tool_json "Read" "git push --force origin main")"
assert_eq "$RC" "0" "non-Bash: Read carrying a git push string exits 0"
run_hook "$(tool_json "Write" "git commit -m x")"
assert_eq "$RC" "0" "non-Bash: Write carrying a git commit string exits 0"

echo "== invalid stdin never blocks =="
run_hook '{"tool_name": "Bash", "tool_input": {"command": "git push"'
assert_eq "$RC" "0" "invalid: truncated JSON exits 0"
run_hook_empty_stdin
assert_eq "$RC" "0" "invalid: empty stdin exits 0"

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

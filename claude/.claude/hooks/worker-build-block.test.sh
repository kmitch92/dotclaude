#!/usr/bin/env bash
# Behavioral tests for worker-build-block.sh (PreToolUse[Bash] hook in the worker
# agent file).
#
# Contract: workers may not run build commands or test suites. Such Bash commands
# are blocked with exit 2 and a stderr reason; other commands are allowed (exit 0).
# Non-Bash tools, invalid stdin, and unparseable commands are allowed (the hook
# never blocks on its own failure).
# Stubbed env: HOME is a throwaway dir, a stub `claude` is first on PATH and any
# PATH dir holding the real `claude` is stripped. The hook is fed hook JSON on
# stdin; it must never execute the command itself. The real jq is used.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$TEST_DIR/worker-build-block.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/worker-build-block-test.XXXXXX")"
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

assert_not_empty() {
  local value="$1" msg="$2"
  if [ -n "$value" ]; then
    pass "$msg"
  else
    fail "$msg (expected non-empty)"
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
echo "stub claude: worker-build-block.sh must not invoke the claude CLI" >&2
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
    session_id: "SID-BUILD", cwd: $d, hook_event_name: "PreToolUse",
    tool_name: $t, tool_use_id: "toolu_build_1",
    tool_input: {command: $c, description: "run command"}
  }'
}

expect_blocked() {
  local cmd="$1"
  run_hook "$(tool_json "Bash" "$cmd")"
  assert_eq "$RC" "2" "blocked [$cmd]: exits 2"
  assert_not_empty "$ERR" "blocked [$cmd]: stderr is non-empty"
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

echo "== build commands are blocked =="
expect_blocked "make"
expect_blocked "make -j8 all"
expect_blocked "ninja"
expect_blocked "./gradlew build"
expect_blocked "gradle test"
expect_blocked "mvn verify"
expect_blocked "./mvnw package"
expect_blocked "tox"
expect_blocked "nox"
expect_blocked "bazel build //..."
expect_blocked "cmake --build build"

echo "== npm/yarn/pnpm/bun build and test are blocked =="
expect_blocked "npm run build"
expect_blocked "npm test"
expect_blocked "yarn build"
expect_blocked "pnpm run test"
expect_blocked "bun run build"
expect_blocked "npm run test:integration"
expect_blocked "npm run e2e"

echo "== rust/go build and test are blocked =="
expect_blocked "cargo build"
expect_blocked "cargo test"
expect_blocked "go test ./..."
expect_blocked "go build ./..."

echo "== python test runners are blocked =="
expect_blocked "pytest"
expect_blocked "pytest -x -q"
expect_blocked "python -m pytest"
expect_blocked "python3 -m pytest -q"
expect_blocked "pytest tests/integration/test_api.py"
expect_blocked "pytest -k e2e tests/"
expect_blocked "python -m unittest discover"

echo "== js test runners are blocked =="
expect_blocked "jest"
expect_blocked "npx jest"
expect_blocked "vitest run"
expect_blocked "npx playwright test"
expect_blocked "cypress run"

echo "== typescript builds are blocked =="
expect_blocked "tsc -b"
expect_blocked "tsc --build"

echo "== docker builds and compose are blocked =="
expect_blocked "docker build ."
expect_blocked "docker compose up"
expect_blocked "docker-compose up -d"

echo "== blocked commands behind separators and sudo are caught =="
expect_blocked "cd /tmp && make"
expect_blocked "echo hi && npm run build"
expect_blocked "sudo make install"

echo "== test files with specific paths are allowed =="
expect_allowed "pytest tests/test_parser.py"
expect_allowed "pytest -q tests/test_parser.py::test_one"
expect_allowed "python -m pytest tests/test_parser.py"
expect_allowed "npx jest src/foo.test.ts"
expect_allowed "vitest run src/foo.test.ts"
expect_allowed "go test ./pkg/foo"
expect_allowed "cargo test --lib parser::tests::one"
expect_allowed "pytest test_parser.py"
expect_allowed "pytest -q test_parser.py::test_one"
expect_allowed "python -m pytest test_parser.py"
expect_allowed "pytest -k slow test_parser.py"

echo "== related but non-build commands are allowed =="
expect_allowed "tsc --noEmit"
expect_allowed "git status"
expect_allowed "ls -la"
expect_allowed "grep -rn \"make\" ."
expect_allowed "node scripts/one-off.js"
expect_allowed "cat Makefile"

echo "== build command mentioned only inside a quoted string is allowed =="
expect_allowed "echo \"npm run build\""

echo "== make_report.sh is allowed (word boundary: not make) =="
expect_allowed "make_report.sh"

echo "== tests from a file name are allowed =="
expect_allowed "bash /home/kiel/dotclaude/claude/.claude/hooks/worker-git-block.test.sh"

echo "== tools other than Bash are allowed =="
run_hook "$(tool_json "Read" "npm run build")"
assert_eq "$RC" "0" "non-Bash: Read carrying a build command exits 0"
run_hook "$(tool_json "Write" "make")"
assert_eq "$RC" "0" "non-Bash: Write carrying a make command exits 0"

echo "== invalid stdin never blocks =="
run_hook '{"tool_name": "Bash", "tool_input": {"command": "npm run build"'
assert_eq "$RC" "0" "invalid: truncated JSON exits 0"
run_hook_empty_stdin
assert_eq "$RC" "0" "invalid: empty stdin exits 0"

echo "== the hook does not execute the command =="
run_hook "$(tool_json "Bash" "touch \"$WORK/marker\"")"
if [ ! -f "$WORK/marker" ]; then
  pass "hook does not execute command: marker file not created"
else
  fail "hook does not execute command: marker file was created"
fi

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

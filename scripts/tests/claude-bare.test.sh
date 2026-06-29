#!/usr/bin/env bash

# =============================================================================
# Test Suite for bin/claude-bare launcher
# =============================================================================
# `claude-bare` launches Claude Code against an ISOLATED, persistent config
# directory so the user's normal ~/.claude is untouched, and so the env var
# does NOT leak into the parent shell (it applies only to the claude child
# process via `exec env`).
#
# Behavioural contract (verified through the public CLI, treating the launcher
# as a black box — we observe what the child `claude` process receives):
#   1. Default bare dir: no CLAUDE_BARE_DIR set -> child claude sees
#      CLAUDE_CONFIG_DIR == "$HOME/.claude-bare".
#   2. Override respected: CLAUDE_BARE_DIR=/path -> child sees
#      CLAUDE_CONFIG_DIR == "/path".
#   3. Argument passthrough: positional args are forwarded verbatim.
#   4. No parent-shell leak: CLAUDE_CONFIG_DIR is unset/empty in the calling
#      shell after invoking the launcher.
#
# Exit status: 0 if all assertions pass, non-zero otherwise.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER_PATH="${SCRIPT_DIR}/../../bin/claude-bare"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# =============================================================================
# Test Framework (mirrors utils.test.sh / detect-install-method.test.sh)
# =============================================================================

assert_true() {
  local description="$1"
  local command="$2"

  TESTS_RUN=$((TESTS_RUN + 1))

  if eval "$command"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "✓ PASS: $description"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "✗ FAIL: $description"
    return 1
  fi
}

assert_equals() {
  local description="$1"
  local expected="$2"
  local actual="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ "$expected" == "$actual" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "✓ PASS: $description"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "✗ FAIL: $description"
    echo "    expected: '$expected'"
    echo "    actual:   '$actual'"
    return 1
  fi
}

print_summary() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Test Summary"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Total tests: $TESTS_RUN"
  echo "Passed:      $TESTS_PASSED"
  echo "Failed:      $TESTS_FAILED"
  echo ""

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "✓ All tests passed"
    return 0
  else
    echo "✗ Some tests failed"
    return 1
  fi
}

# =============================================================================
# Fixture Helpers
# =============================================================================

# Per-suite sandbox. SANDBOX holds an isolated HOME, a stub-bin dir prepended
# to PATH, and a capture file the stub `claude` writes its received env/args to.
SANDBOX=""
STUB_BIN=""
CAPTURE_FILE=""

setup_sandbox() {
  SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/claude-bare-test.XXXXXX")"
  STUB_BIN="${SANDBOX}/bin"
  CAPTURE_FILE="${SANDBOX}/capture"
  mkdir -p "$STUB_BIN"

  # Stub `claude` placed earlier on PATH than any real binary. It records the
  # CLAUDE_CONFIG_DIR it was invoked with and every positional argument, then
  # exits cleanly. This lets us observe — as a black box — exactly what the
  # launcher hands to the child process.
  cat > "${STUB_BIN}/claude" <<'STUB'
#!/usr/bin/env bash
{
  printf 'CONFIG_DIR=%s\n' "${CLAUDE_CONFIG_DIR:-<UNSET>}"
  printf 'ARGC=%s\n' "$#"
  for arg in "$@"; do
    printf 'ARG=%s\n' "$arg"
  done
} > "$CAPTURE_FILE"
exit 0
STUB
  chmod +x "${STUB_BIN}/claude"
}

teardown_sandbox() {
  [[ -n "$SANDBOX" && -d "$SANDBOX" ]] && rm -rf "$SANDBOX"
  SANDBOX=""
}

trap 'teardown_sandbox' EXIT

# Run the launcher in the sandboxed environment. The stub bin dir is prepended
# to PATH so the stub `claude` shadows any real install. Extra leading
# VAR=value assignments may precede a `--` separator for env overrides.
#   run_launcher [VAR=value ...] [--] [launcher args ...]
run_launcher() {
  local -a env_overrides=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift; break ;;
      *=*) env_overrides+=("$1"); shift ;;
      *) break ;;
    esac
  done

  # bash 3.2 + `set -u`: expanding an empty array via "${arr[@]}" errors as an
  # unbound variable, so guard the expansion on a non-zero element count.
  if [[ ${#env_overrides[@]} -gt 0 ]]; then
    env -i \
      HOME="$SANDBOX" \
      PATH="${STUB_BIN}:/usr/bin:/bin" \
      CAPTURE_FILE="$CAPTURE_FILE" \
      "${env_overrides[@]}" \
      "$LAUNCHER_PATH" "$@"
  else
    env -i \
      HOME="$SANDBOX" \
      PATH="${STUB_BIN}:/usr/bin:/bin" \
      CAPTURE_FILE="$CAPTURE_FILE" \
      "$LAUNCHER_PATH" "$@"
  fi
}

# Read a single captured field (CONFIG_DIR / ARGC) from the capture file.
captured_field() {
  local key="$1"
  [[ -f "$CAPTURE_FILE" ]] || { echo "<NO_CAPTURE>"; return 0; }
  sed -n "s/^${key}=//p" "$CAPTURE_FILE" | head -n1
}

# Read all captured positional args, newline-joined, in order.
captured_args() {
  [[ -f "$CAPTURE_FILE" ]] || { echo "<NO_CAPTURE>"; return 0; }
  sed -n 's/^ARG=//p' "$CAPTURE_FILE"
}

# =============================================================================
# Test Suite
# =============================================================================

test_default_bare_dir() {
  setup_sandbox

  run_launcher >/dev/null 2>&1 || true

  assert_equals "default invokes claude with CLAUDE_CONFIG_DIR=\$HOME/.claude-bare" \
    "${SANDBOX}/.claude-bare" \
    "$(captured_field CONFIG_DIR)"

  teardown_sandbox
}

test_override_respected() {
  setup_sandbox

  local override="${SANDBOX}/custom-bare-dir"
  run_launcher "CLAUDE_BARE_DIR=${override}" -- >/dev/null 2>&1 || true

  assert_equals "CLAUDE_BARE_DIR override sets child CLAUDE_CONFIG_DIR" \
    "$override" \
    "$(captured_field CONFIG_DIR)"

  teardown_sandbox
}

test_argument_passthrough() {
  setup_sandbox

  run_launcher -- --version foo bar >/dev/null 2>&1 || true

  assert_equals "forwards correct number of positional args" \
    "3" \
    "$(captured_field ARGC)"

  local expected
  expected="$(printf '%s\n' '--version' 'foo' 'bar')"
  assert_equals "forwards '--version foo bar' verbatim to claude" \
    "$expected" \
    "$(captured_args)"

  teardown_sandbox
}

test_no_parent_shell_leak() {
  setup_sandbox

  # Invoke in the *current* shell environment (not env -i) and confirm the
  # launcher does not export/persist CLAUDE_CONFIG_DIR into the caller. We use
  # a local PATH/HOME so the stub is used, but observe THIS shell afterwards.
  local before="${CLAUDE_CONFIG_DIR:-<UNSET>}"

  PATH="${STUB_BIN}:${PATH}" HOME="$SANDBOX" CAPTURE_FILE="$CAPTURE_FILE" \
    "$LAUNCHER_PATH" >/dev/null 2>&1 || true

  local after="${CLAUDE_CONFIG_DIR:-<UNSET>}"

  assert_equals "CLAUDE_CONFIG_DIR does not leak into the calling shell" \
    "$before" \
    "$after"

  # And confirm the child genuinely received it (so the absence above proves
  # isolation, not a no-op launcher).
  assert_equals "child still received an isolated CLAUDE_CONFIG_DIR" \
    "${SANDBOX}/.claude-bare" \
    "$(captured_field CONFIG_DIR)"

  teardown_sandbox
}

# =============================================================================
# Main
# =============================================================================

main() {
  echo "Testing claude-bare launcher from: $LAUNCHER_PATH"
  echo "Bash version: $BASH_VERSION"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Testing bin/claude-bare"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Guard: if the launcher is missing or not executable, every behaviour below
  # will fail — that is the expected RED state. We still run each test so the
  # output enumerates every behaviour that must eventually pass.
  if [[ ! -x "$LAUNCHER_PATH" ]]; then
    echo "ℹ bin/claude-bare not found or not executable at $LAUNCHER_PATH (expected during RED)"
    echo ""
  fi

  test_default_bare_dir
  test_override_respected
  test_argument_passthrough
  test_no_parent_shell_leak

  print_summary
}

main "$@"

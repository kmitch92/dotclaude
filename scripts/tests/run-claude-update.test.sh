#!/usr/bin/env bash

# =============================================================================
# Test Suite for run_claude_update() in utils.sh
# =============================================================================
# Thin orchestrator that wires detect_claude_install_method +
# get_claude_update_command together so install.sh can delegate its update
# branch to a single testable function.
#
# Signature:
#   run_claude_update <os>
#
# Where <os> is "macos" or "linux" (matches detect_os output).
#
# Behavior contract (final):
#   1. Validate args: exactly 1 arg; must be "macos" or "linux". Otherwise
#      print_error and return 1. No eval.
#   2. Resolve claude binary via `command -v claude`. If not found,
#      print_error and return 1. No eval.
#   3. Call detect_claude_install_method <binary>. If that function itself
#      returns non-zero (e.g. non-executable), print_error and return 1.
#      No eval.
#   4. Call get_claude_update_command <method> <os>:
#        rc=0 -> capture cmd string. If method==npm AND os==linux AND
#                `_npm_global_writable` returns non-zero, prefix cmd with
#                "sudo ". Echo "Running: <final-cmd>" via print_info, then
#                `eval "<final-cmd>"`. Return eval's exit status.
#        rc=2 -> print_warning naming the resolved binary path and
#                instructing the user to update manually. Return 2. No eval.
#        rc=anything else -> print_error. Return 1. No eval.
#
# Design decisions (flagged for review):
#   * `_npm_global_writable` is a separate helper in utils.sh so tests can
#     shim it without touching real filesystem permissions. Returns 0 if the
#     npm global root (per `npm root -g`) is writable by the current user,
#     non-zero otherwise.
#   * Informational "Running: ..." line goes to stdout (via print_info) so
#     CI logs capture it without stderr noise.
#   * On detect_claude_install_method rc=1 (non-executable, missing arg),
#     run_claude_update returns 1 — this is environmental, not an "unknown
#     installer" case (which returns 2 via get_claude_update_command).
#   * Command emitted by get_claude_update_command is trusted because its
#     output comes from a fixed table, so `eval` is safe here.
#
# Test strategy:
#   * All tests run in subshells with shimmed `command`, `claude`, `brew`,
#     `npm`, `sudo`, and the utils-sh functions it depends on. No real
#     process invocation occurs.
#   * Each command shim appends its argv to a temp "invocation log" file
#     so tests can assert exactly which command was eval'd.
#
# Bash 3.2 compatible (macOS default).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="${SCRIPT_DIR}/../utils.sh"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

source "$UTILS_PATH"

# =============================================================================
# Test Framework (mirrors sibling test files)
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

assert_return_code() {
  local description="$1"
  local expected_rc="$2"
  local actual_rc="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ "$expected_rc" == "$actual_rc" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "✓ PASS: $description"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "✗ FAIL: $description"
    echo "    expected return code: $expected_rc"
    echo "    actual return code:   $actual_rc"
    return 1
  fi
}

assert_contains() {
  local description="$1"
  local needle="$2"
  local haystack="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  case "$haystack" in
    *"$needle"*)
      TESTS_PASSED=$((TESTS_PASSED + 1))
      echo "✓ PASS: $description"
      return 0
      ;;
    *)
      TESTS_FAILED=$((TESTS_FAILED + 1))
      echo "✗ FAIL: $description"
      echo "    needle:   '$needle'"
      echo "    haystack: '$haystack'"
      return 1
      ;;
  esac
}

assert_not_contains() {
  local description="$1"
  local needle="$2"
  local haystack="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  case "$haystack" in
    *"$needle"*)
      TESTS_FAILED=$((TESTS_FAILED + 1))
      echo "✗ FAIL: $description"
      echo "    should NOT contain: '$needle'"
      echo "    haystack:           '$haystack'"
      return 1
      ;;
    *)
      TESTS_PASSED=$((TESTS_PASSED + 1))
      echo "✓ PASS: $description"
      return 0
      ;;
  esac
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
# Shim Infrastructure
#
# build_shim_env emits a block of shell code (as a string) that, when
# sourced inside a subshell, overrides:
#   - command      (intercepts `command -v claude`)
#   - detect_claude_install_method (returns the fixtured method)
#   - get_claude_update_command    (delegated to real utils.sh — already
#                                   pure and tested; no need to shim)
#   - _npm_global_writable         (returns 0 or 1 per fixture)
#   - claude / brew / npm / sudo   (append argv to LOG_FILE)
#
# Arguments to build_shim_env:
#   $1 = log file path
#   $2 = claude-path-to-report (or empty string to fake "not found")
#   $3 = method-to-report ("native" | "brew" | "npm" | "unknown")
#   $4 = npm-writable flag ("0" means writable i.e. no sudo; "1" means
#        not writable i.e. sudo needed). Only consulted when method==npm.
#   $5 = claude-exit-code for the shimmed claude binary when `claude update`
#        is invoked via eval (likewise brew/npm/sudo share this).
# =============================================================================

build_shim_env() {
  local log_file="$1"
  local claude_path="$2"
  local method="$3"
  local npm_writable="$4"
  local exit_code="$5"

  cat <<SHIM
# --- shim header -------------------------------------------------------------
LOG_FILE="$log_file"
SHIM_EXIT_CODE="$exit_code"

# Record every invocation of a shimmed binary to LOG_FILE.
_record() {
  # Write "bin:arg1 arg2 ..." per line.
  local bin="\$1"
  shift
  printf '%s:%s\n' "\$bin" "\$*" >> "\$LOG_FILE"
}

# Shim `command` — intercept only `command -v claude`; delegate everything
# else to the builtin to avoid breaking detect_os and friends.
command() {
  if [ "\${1:-}" = "-v" ] && [ "\${2:-}" = "claude" ]; then
SHIM

  if [ -z "$claude_path" ]; then
    cat <<'SHIM_NO_CLAUDE'
    return 1
SHIM_NO_CLAUDE
  else
    cat <<SHIM_CLAUDE
    echo "$claude_path"
    return 0
SHIM_CLAUDE
  fi

  cat <<'SHIM_TAIL'
  fi
  builtin command "$@"
}

# Shim detect_claude_install_method — return fixtured method.
SHIM_TAIL

  cat <<SHIM_METHOD
detect_claude_install_method() {
  echo "$method"
  return 0
}

# Shim _npm_global_writable. "0" in fixture means writable (rc 0),
# "1" in fixture means NOT writable (rc 1).
_npm_global_writable() {
  return $npm_writable
}
SHIM_METHOD

  cat <<'SHIM_BINS'

# Shim the actual update-tool binaries: record invocation and exit with
# the fixture-controlled exit code.
claude() { _record claude "$@"; return "$SHIM_EXIT_CODE"; }
brew()   { _record brew   "$@"; return "$SHIM_EXIT_CODE"; }
npm()    { _record npm    "$@"; return "$SHIM_EXIT_CODE"; }
sudo()   { _record sudo   "$@"; return "$SHIM_EXIT_CODE"; }

# Export nothing — we rely on function definitions being in-scope for the
# subshell that eval's this block.
# --- end shim header ---------------------------------------------------------
SHIM_BINS
}

# Run run_claude_update inside a fully-shimmed subshell and capture its
# stdout, stderr, return code, and the invocation log.
#
# Usage:
#   run_with_shims \
#     <log_file> <claude_path> <method> <npm_writable> <exit_code> \
#     <os-arg-passed-to-run_claude_update> [extra-args...]
#
# Echoes:
#   rc on stdout (caller should capture separately via variable assignment;
#   we instead set globals LAST_STDOUT / LAST_STDERR / LAST_RC / LAST_LOG).
run_with_shims() {
  local log_file="$1"; shift
  local claude_path="$1"; shift
  local method="$1"; shift
  local npm_writable="$1"; shift
  local exit_code="$1"; shift
  # Remaining args are passed to run_claude_update.

  : > "$log_file"  # truncate log

  local stdout_file stderr_file
  stdout_file="$(mktemp "${TMPDIR:-/tmp}/rcu-stdout.XXXXXX")"
  stderr_file="$(mktemp "${TMPDIR:-/tmp}/rcu-stderr.XXXXXX")"

  local shim_block
  shim_block="$(build_shim_env "$log_file" "$claude_path" "$method" "$npm_writable" "$exit_code")"

  (
    # Subshell: re-source utils so run_claude_update (once implemented) is
    # defined, then install shims AFTER sourcing so they override library
    # functions. If run_claude_update is not yet defined (RED phase), the
    # call below will emit "command not found" on stderr, producing rc=127
    # — which is non-zero and therefore correctly fails every assertion.
    # Re-sourcing emits harmless `readonly variable` warnings because the
    # parent already sourced utils.sh; discard stderr for that one line.
    # shellcheck disable=SC1090
    source "$UTILS_PATH" 2>/dev/null
    eval "$shim_block"
    run_claude_update "$@"
  ) >"$stdout_file" 2>"$stderr_file"
  local rc=$?

  LAST_STDOUT="$(cat "$stdout_file")"
  LAST_STDERR="$(cat "$stderr_file")"
  LAST_RC="$rc"
  if [ -f "$log_file" ]; then
    LAST_LOG="$(cat "$log_file")"
  else
    LAST_LOG=""
  fi

  rm -f "$stdout_file" "$stderr_file"
}

make_tmp_log() {
  mktemp "${TMPDIR:-/tmp}/rcu-log.XXXXXX"
}

# =============================================================================
# Test Suite
# =============================================================================

test_native_macos_runs_claude_update() {
  local log; log="$(make_tmp_log)"
  run_with_shims "$log" "/usr/local/bin/claude" "native" "0" "0" "macos"

  assert_return_code "native+macos returns 0" "0" "$LAST_RC"
  assert_contains "native+macos log records claude update" "claude:update" "$LAST_LOG"
  assert_not_contains "native+macos does not invoke brew" "brew:" "$LAST_LOG"
  assert_not_contains "native+macos does not invoke npm"  "npm:"  "$LAST_LOG"
  assert_not_contains "native+macos does not invoke sudo" "sudo:" "$LAST_LOG"
  assert_contains "native+macos prints 'Running: claude update' to stdout" \
    "Running: claude update" "$LAST_STDOUT"

  rm -f "$log"
}

test_native_linux_runs_claude_update() {
  local log; log="$(make_tmp_log)"
  run_with_shims "$log" "/home/u/.local/bin/claude" "native" "0" "0" "linux"

  assert_return_code "native+linux returns 0" "0" "$LAST_RC"
  assert_contains "native+linux log records claude update" "claude:update" "$LAST_LOG"
  assert_not_contains "native+linux does not invoke sudo" "sudo:" "$LAST_LOG"

  rm -f "$log"
}

test_brew_macos_runs_brew_upgrade() {
  local log; log="$(make_tmp_log)"
  run_with_shims "$log" "/opt/homebrew/bin/claude" "brew" "0" "0" "macos"

  assert_return_code "brew+macos returns 0" "0" "$LAST_RC"
  assert_contains "brew+macos log records brew upgrade claude" "brew:upgrade claude" "$LAST_LOG"
  assert_not_contains "brew+macos does not invoke claude directly" "claude:" "$LAST_LOG"
  assert_not_contains "brew+macos does not invoke npm" "npm:" "$LAST_LOG"
  assert_not_contains "brew+macos does not invoke sudo" "sudo:" "$LAST_LOG"

  rm -f "$log"
}

test_npm_macos_runs_npm_install_no_sudo() {
  local log; log="$(make_tmp_log)"
  # On macos sudo is never added regardless of writability — only
  # npm+linux+not-writable triggers the sudo prefix.
  run_with_shims "$log" "/usr/local/bin/claude" "npm" "1" "0" "macos"

  assert_return_code "npm+macos returns 0" "0" "$LAST_RC"
  assert_contains "npm+macos log records npm install -g @anthropic-ai/claude-code@latest" \
    "npm:install -g @anthropic-ai/claude-code@latest" "$LAST_LOG"
  assert_not_contains "npm+macos never prefixes sudo" "sudo:" "$LAST_LOG"

  rm -f "$log"
}

test_npm_linux_writable_root_runs_npm_install_no_sudo() {
  local log; log="$(make_tmp_log)"
  # "0" for npm_writable means _npm_global_writable returns 0 (writable).
  run_with_shims "$log" "/home/u/.npm-global/bin/claude" "npm" "0" "0" "linux"

  assert_return_code "npm+linux(writable) returns 0" "0" "$LAST_RC"
  assert_contains "npm+linux(writable) log records npm install -g ..." \
    "npm:install -g @anthropic-ai/claude-code@latest" "$LAST_LOG"
  assert_not_contains "npm+linux(writable) does NOT prefix sudo" "sudo:" "$LAST_LOG"

  rm -f "$log"
}

test_npm_linux_non_writable_root_runs_sudo_npm_install() {
  local log; log="$(make_tmp_log)"
  # "1" for npm_writable means _npm_global_writable returns 1 (NOT writable),
  # so run_claude_update should prefix "sudo ".
  run_with_shims "$log" "/usr/lib/node_modules/.bin/claude" "npm" "1" "0" "linux"

  assert_return_code "npm+linux(non-writable) returns 0" "0" "$LAST_RC"
  assert_contains "npm+linux(non-writable) log records sudo invocation" \
    "sudo:npm install -g @anthropic-ai/claude-code@latest" "$LAST_LOG"

  rm -f "$log"
}

test_unknown_method_warns_and_returns_2_without_eval() {
  local log; log="$(make_tmp_log)"
  run_with_shims "$log" "/opt/custom/claude" "unknown" "0" "0" "macos"

  assert_return_code "unknown method returns 2" "2" "$LAST_RC"
  assert_equals "unknown method produces no invocation log (no eval)" "" "$LAST_LOG"

  # Warning must mention the resolved path so the user knows what to update.
  # We accept the warning appearing on EITHER stream since print_warning
  # currently writes to stdout, but a future change to stderr should not
  # break this assertion.
  local combined="${LAST_STDOUT}${LAST_STDERR}"
  assert_contains "unknown method warning references binary path" \
    "/opt/custom/claude" "$combined"
  assert_contains "unknown method warning instructs manual update" \
    "manually" "$combined"

  rm -f "$log"
}

test_claude_not_installed_errors_without_eval() {
  local log; log="$(make_tmp_log)"
  # Empty claude_path -> `command -v claude` shim returns 1.
  run_with_shims "$log" "" "native" "0" "0" "macos"

  assert_true "claude-not-found returns non-zero" "[ \"$LAST_RC\" -ne 0 ]"
  assert_equals "claude-not-found produces no invocation log" "" "$LAST_LOG"

  rm -f "$log"
}

test_invalid_os_errors_without_eval() {
  local log; log="$(make_tmp_log)"
  run_with_shims "$log" "/usr/local/bin/claude" "native" "0" "0" "windows"

  assert_return_code "invalid OS returns 1" "1" "$LAST_RC"
  assert_equals "invalid OS produces no invocation log" "" "$LAST_LOG"

  rm -f "$log"
}

test_missing_os_arg_errors_without_eval() {
  local log; log="$(make_tmp_log)"
  # Call with zero extra args beyond the shim fixture — run_claude_update
  # receives no positional arg.
  run_with_shims "$log" "/usr/local/bin/claude" "native" "0" "0"

  assert_return_code "missing OS arg returns 1" "1" "$LAST_RC"
  assert_equals "missing OS arg produces no invocation log" "" "$LAST_LOG"

  rm -f "$log"
}

test_eval_failure_propagates_exit_code() {
  local log; log="$(make_tmp_log)"
  # Shimmed claude exits 42 when invoked — run_claude_update must return 42.
  run_with_shims "$log" "/usr/local/bin/claude" "native" "0" "42" "macos"

  assert_return_code "eval failure propagates exit code from underlying tool" \
    "42" "$LAST_RC"
  assert_contains "underlying tool WAS invoked" "claude:update" "$LAST_LOG"

  rm -f "$log"
}

test_eval_failure_npm_linux_sudo_propagates_exit_code() {
  # Regression: sudo-prefixed path must also propagate non-zero rc.
  local log; log="$(make_tmp_log)"
  run_with_shims "$log" "/usr/lib/node_modules/.bin/claude" "npm" "1" "7" "linux"

  assert_return_code "sudo+npm failure propagates exit code" "7" "$LAST_RC"
  assert_contains "sudo WAS invoked even though it failed" \
    "sudo:npm install -g @anthropic-ai/claude-code@latest" "$LAST_LOG"

  rm -f "$log"
}

# =============================================================================
# Guard: function must exist. Prevents silent false-green during RED.
# =============================================================================

test_function_is_defined() {
  assert_true "run_claude_update is defined in utils.sh" \
    "declare -F run_claude_update >/dev/null 2>&1"
}

test_npm_writable_helper_is_defined() {
  assert_true "_npm_global_writable helper is defined in utils.sh" \
    "declare -F _npm_global_writable >/dev/null 2>&1"
}

# =============================================================================
# Main
# =============================================================================

main() {
  if [[ ! -f "$UTILS_PATH" ]]; then
    echo "✗ ERROR: utils.sh not found at $UTILS_PATH"
    exit 1
  fi

  echo "Testing run_claude_update() from: $UTILS_PATH"
  echo "Bash version: $BASH_VERSION"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Testing run_claude_update()"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if ! declare -F run_claude_update >/dev/null 2>&1; then
    echo "ℹ run_claude_update is not defined in utils.sh (expected during RED)"
    echo ""
  fi

  test_function_is_defined
  test_npm_writable_helper_is_defined

  # Happy paths
  test_native_macos_runs_claude_update
  test_native_linux_runs_claude_update
  test_brew_macos_runs_brew_upgrade
  test_npm_macos_runs_npm_install_no_sudo
  test_npm_linux_writable_root_runs_npm_install_no_sudo
  test_npm_linux_non_writable_root_runs_sudo_npm_install

  # Branch: unknown method
  test_unknown_method_warns_and_returns_2_without_eval

  # Error paths
  test_claude_not_installed_errors_without_eval
  test_invalid_os_errors_without_eval
  test_missing_os_arg_errors_without_eval

  # Exit-code propagation
  test_eval_failure_propagates_exit_code
  test_eval_failure_npm_linux_sudo_propagates_exit_code

  print_summary
}

main "$@"

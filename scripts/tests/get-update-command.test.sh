#!/usr/bin/env bash

# =============================================================================
# Test Suite for get_claude_update_command() in utils.sh
# =============================================================================
# Pure function that maps (install-method, os) -> update-command string.
#
# Signature:
#   get_claude_update_command <method> <os>
#
# Inputs:
#   <method>: native | brew | npm | unknown
#   <os>:     macos | linux   (matches detect_os output)
#
# Contract (final — tie-breaks resolved for simplicity/symmetry):
#   method   | os           | stdout                                            | return
#   ---------|--------------|---------------------------------------------------|-------
#   native   | macos, linux | claude update                                     | 0
#   brew     | macos, linux | brew upgrade claude                               | 0
#   npm      | macos, linux | npm install -g @anthropic-ai/claude-code@latest   | 0
#   unknown  | macos, linux | UNKNOWN                                           | 2
#   missing args / empty args / invalid method / invalid os   | (none) | 1
#
# Tie-break notes:
#   * brew treated identically on macOS and Linux (linuxbrew is legitimate,
#     and install.sh already runs `brew upgrade claude` unconditionally).
#   * unknown returns 2 (distinct from 0 success and 1 arg-error) so callers
#     can branch: 0 -> eval; 1 -> programmer error; 2 -> warn user to update
#     manually. Sentinel on stdout is the literal string "UNKNOWN".
#   * No stdout on arg-validation failures (return 1) so callers using
#     `cmd="$(get_claude_update_command ...)"` never `eval` junk.
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
# Test Framework (mirrors detect-install-method.test.sh)
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
# Helpers
# =============================================================================

# Capture stdout and return code in one call without leaking either.
# Usage:
#   run_capture <varname_stdout> <varname_rc> <fn> [args...]
run_capture() {
  local __out_var="$1"
  local __rc_var="$2"
  shift 2
  local __out __rc
  # 2>/dev/null suppresses noise from missing function while still letting
  # `declare -F` guard tests detect definition.
  __out="$("$@" 2>/dev/null)"
  __rc=$?
  # shellcheck disable=SC2140
  printf -v "$__out_var" '%s' "$__out"
  # shellcheck disable=SC2140
  printf -v "$__rc_var" '%s' "$__rc"
}

# =============================================================================
# Test Suite — valid (method, os) combinations
# =============================================================================

test_native_macos() {
  local out rc
  run_capture out rc get_claude_update_command native macos
  assert_equals "native on macos echoes 'claude update'" "claude update" "$out"
  assert_return_code "native on macos returns 0" "0" "$rc"
}

test_native_linux() {
  local out rc
  run_capture out rc get_claude_update_command native linux
  assert_equals "native on linux echoes 'claude update'" "claude update" "$out"
  assert_return_code "native on linux returns 0" "0" "$rc"
}

test_brew_macos() {
  local out rc
  run_capture out rc get_claude_update_command brew macos
  assert_equals "brew on macos echoes 'brew upgrade claude'" "brew upgrade claude" "$out"
  assert_return_code "brew on macos returns 0" "0" "$rc"
}

test_brew_linux() {
  # Tie-break: brew treated symmetrically across OSes. linuxbrew is a
  # supported path and `brew upgrade claude` works identically there.
  local out rc
  run_capture out rc get_claude_update_command brew linux
  assert_equals "brew on linux echoes 'brew upgrade claude'" "brew upgrade claude" "$out"
  assert_return_code "brew on linux returns 0" "0" "$rc"
}

test_npm_macos() {
  local out rc
  run_capture out rc get_claude_update_command npm macos
  assert_equals "npm on macos echoes npm global install command" \
    "npm install -g @anthropic-ai/claude-code@latest" "$out"
  assert_return_code "npm on macos returns 0" "0" "$rc"
}

test_npm_linux() {
  local out rc
  run_capture out rc get_claude_update_command npm linux
  assert_equals "npm on linux echoes npm global install command" \
    "npm install -g @anthropic-ai/claude-code@latest" "$out"
  assert_return_code "npm on linux returns 0" "0" "$rc"
}

# =============================================================================
# Test Suite — unknown sentinel
# =============================================================================

test_unknown_macos() {
  local out rc
  run_capture out rc get_claude_update_command unknown macos
  assert_equals "unknown on macos echoes 'UNKNOWN' sentinel" "UNKNOWN" "$out"
  assert_return_code "unknown on macos returns 2 (distinct from 0/1)" "2" "$rc"
}

test_unknown_linux() {
  local out rc
  run_capture out rc get_claude_update_command unknown linux
  assert_equals "unknown on linux echoes 'UNKNOWN' sentinel" "UNKNOWN" "$out"
  assert_return_code "unknown on linux returns 2 (distinct from 0/1)" "2" "$rc"
}

# =============================================================================
# Test Suite — invalid inputs (all must return 1 with no stdout)
# =============================================================================

test_missing_both_args() {
  local out rc
  run_capture out rc get_claude_update_command
  assert_equals "missing both args produces no stdout" "" "$out"
  assert_return_code "missing both args returns 1" "1" "$rc"
}

test_missing_os_arg() {
  local out rc
  run_capture out rc get_claude_update_command native
  assert_equals "missing os arg produces no stdout" "" "$out"
  assert_return_code "missing os arg returns 1" "1" "$rc"
}

test_empty_method_arg() {
  local out rc
  run_capture out rc get_claude_update_command "" macos
  assert_equals "empty method produces no stdout" "" "$out"
  assert_return_code "empty method returns 1" "1" "$rc"
}

test_empty_os_arg() {
  local out rc
  run_capture out rc get_claude_update_command native ""
  assert_equals "empty os produces no stdout" "" "$out"
  assert_return_code "empty os returns 1" "1" "$rc"
}

test_both_empty_args() {
  local out rc
  run_capture out rc get_claude_update_command "" ""
  assert_equals "both empty args produce no stdout" "" "$out"
  assert_return_code "both empty args returns 1" "1" "$rc"
}

test_invalid_method_pip() {
  local out rc
  run_capture out rc get_claude_update_command pip macos
  assert_equals "invalid method 'pip' produces no stdout" "" "$out"
  assert_return_code "invalid method 'pip' returns 1" "1" "$rc"
}

test_invalid_method_garbage() {
  local out rc
  run_capture out rc get_claude_update_command "; rm -rf /" macos
  assert_equals "invalid method (shell-meta) produces no stdout" "" "$out"
  assert_return_code "invalid method (shell-meta) returns 1" "1" "$rc"
}

test_invalid_os_windows() {
  local out rc
  run_capture out rc get_claude_update_command native windows
  assert_equals "invalid os 'windows' produces no stdout" "" "$out"
  assert_return_code "invalid os 'windows' returns 1" "1" "$rc"
}

test_invalid_os_unknown() {
  # detect_os returns "unknown" when OS cannot be identified. The update
  # command function must reject this — callers cannot update on an
  # unrecognised OS regardless of install method.
  local out rc
  run_capture out rc get_claude_update_command brew unknown
  assert_equals "os 'unknown' (from detect_os) produces no stdout" "" "$out"
  assert_return_code "os 'unknown' returns 1" "1" "$rc"
}

test_both_args_invalid() {
  local out rc
  run_capture out rc get_claude_update_command pip windows
  assert_equals "both args invalid produce no stdout" "" "$out"
  assert_return_code "both args invalid returns 1" "1" "$rc"
}

test_case_sensitivity_method() {
  # Method must be lowercase — matches detect_claude_install_method output.
  local out rc
  run_capture out rc get_claude_update_command NATIVE macos
  assert_equals "uppercase method 'NATIVE' produces no stdout" "" "$out"
  assert_return_code "uppercase method 'NATIVE' returns 1" "1" "$rc"
}

test_case_sensitivity_os() {
  # OS must be lowercase — matches detect_os output.
  local out rc
  run_capture out rc get_claude_update_command native MACOS
  assert_equals "uppercase os 'MACOS' produces no stdout" "" "$out"
  assert_return_code "uppercase os 'MACOS' returns 1" "1" "$rc"
}

# =============================================================================
# Guard: function must exist. Prevents silent false-green during RED.
# =============================================================================

test_function_is_defined() {
  assert_true "get_claude_update_command is defined in utils.sh" \
    "declare -F get_claude_update_command >/dev/null 2>&1"
}

# =============================================================================
# Main
# =============================================================================

main() {
  if [[ ! -f "$UTILS_PATH" ]]; then
    echo "✗ ERROR: utils.sh not found at $UTILS_PATH"
    exit 1
  fi

  echo "Testing get_claude_update_command() from: $UTILS_PATH"
  echo "Bash version: $BASH_VERSION"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Testing get_claude_update_command()"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if ! declare -F get_claude_update_command >/dev/null 2>&1; then
    echo "ℹ get_claude_update_command is not defined in utils.sh (expected during RED)"
    echo ""
  fi

  test_function_is_defined

  # Valid combinations
  test_native_macos
  test_native_linux
  test_brew_macos
  test_brew_linux
  test_npm_macos
  test_npm_linux

  # Unknown sentinel
  test_unknown_macos
  test_unknown_linux

  # Invalid inputs
  test_missing_both_args
  test_missing_os_arg
  test_empty_method_arg
  test_empty_os_arg
  test_both_empty_args
  test_invalid_method_pip
  test_invalid_method_garbage
  test_invalid_os_windows
  test_invalid_os_unknown
  test_both_args_invalid
  test_case_sensitivity_method
  test_case_sensitivity_os

  print_summary
}

main "$@"

#!/usr/bin/env bash

# =============================================================================
# Test Suite for utils.sh - Bash 3.2 Compatibility
# =============================================================================
# Tests confirm() function with bash 3.2 (macOS default) and bash 4+
# =============================================================================

set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="${SCRIPT_DIR}/../utils.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Load utilities to test
source "$UTILS_PATH"

# =============================================================================
# Test Framework
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

assert_false() {
  local description="$1"
  local command="$2"

  TESTS_RUN=$((TESTS_RUN + 1))

  if eval "$command"; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "✗ FAIL: $description"
    return 1
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "✓ PASS: $description"
    return 0
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
# Test Suite: confirm() Function
# =============================================================================

test_confirm() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Testing confirm() function - Bash 3.2 Compatibility"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Bash version: $BASH_VERSION"
  echo ""

  # Test lowercase 'y' returns true (exit code 0)
  assert_true "confirm returns true for lowercase 'y'" \
    "echo 'y' | confirm 'Test prompt'"

  # Test uppercase 'Y' returns true (exit code 0)
  assert_true "confirm returns true for uppercase 'Y'" \
    "echo 'Y' | confirm 'Test prompt'"

  # Test lowercase 'n' returns false (exit code 1)
  assert_false "confirm returns false for lowercase 'n'" \
    "echo 'n' | confirm 'Test prompt'"

  # Test uppercase 'N' returns false (exit code 1)
  assert_false "confirm returns false for uppercase 'N'" \
    "echo 'N' | confirm 'Test prompt'"

  # Test empty input returns false (exit code 1)
  assert_false "confirm returns false for empty input" \
    "echo '' | confirm 'Test prompt'"

  # Test random input returns false (exit code 1)
  assert_false "confirm returns false for 'yes'" \
    "echo 'yes' | confirm 'Test prompt'"

  assert_false "confirm returns false for 'no'" \
    "echo 'no' | confirm 'Test prompt'"

  assert_false "confirm returns false for 'x'" \
    "echo 'x' | confirm 'Test prompt'"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
  # Verify utils.sh exists
  if [[ ! -f "$UTILS_PATH" ]]; then
    echo "✗ ERROR: utils.sh not found at $UTILS_PATH"
    exit 1
  fi

  echo "Testing utils.sh from: $UTILS_PATH"

  # Run test suite
  test_confirm

  # Print summary and exit with appropriate code
  print_summary
}

main "$@"

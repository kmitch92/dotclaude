#!/usr/bin/env bash

# =============================================================================
# Test Suite for ensure_path_in_rc() in utils.sh
# =============================================================================
# Verifies behaviour of:
#   ensure_path_in_rc <rc_file>
#
# Contract:
#   - Idempotently ensures <rc_file> contains a marker-delimited, self-guarding
#     block that puts ~/.local/bin on PATH at shell startup.
#   - Start marker line: "# >>> dotclaude (claude config) PATH >>>"
#   - End marker line:   "# <<< dotclaude (claude config) PATH <<<"
#   - Between the markers it writes a POSIX-safe guarded export whose PATH line
#     is the LITERAL string  export PATH="$HOME/.local/bin:$PATH"  (NOT an
#     install-time-expanded absolute path), so it evaluates per-user at startup.
#   - Appends the block when absent; preserves any pre-existing content.
#   - When the marker is already present: no-op (file byte-for-byte unchanged).
#   - Creates the file if it does not yet exist.
#   - Returns 0 on success.
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

# Fixed strings pinned by the contract.
START_MARKER='# >>> dotclaude (claude config) PATH >>>'
END_MARKER='# <<< dotclaude (claude config) PATH <<<'
LITERAL_PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

# =============================================================================
# Test Framework (mirrors backup-dir-excluding.test.sh)
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

SANDBOX_ROOT=""

cleanup() {
  if [[ -n "$SANDBOX_ROOT" && -d "$SANDBOX_ROOT" ]]; then
    rm -rf "$SANDBOX_ROOT"
  fi
}
trap cleanup EXIT

# =============================================================================
# Test Suite: ensure_path_in_rc()
# =============================================================================

test_ensure_path_in_rc() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Testing ensure_path_in_rc() function"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Bash version: $BASH_VERSION"
  echo ""

  # ---------------------------------------------------------------------------
  # Behaviour 1 + 2: adds the guarded block when absent, preserves prior content.
  # ---------------------------------------------------------------------------
  local rc1="${SANDBOX_ROOT}/rc-absent"
  printf 'export FOO=1\n' > "$rc1"

  assert_true "ADD: returns success (exit 0) when marker absent" \
    "ensure_path_in_rc \"$rc1\""

  assert_true "ADD: file contains the start marker line" \
    "grep -qF \"\$START_MARKER\" \"$rc1\""
  assert_true "ADD: file contains the end marker line" \
    "grep -qF \"\$END_MARKER\" \"$rc1\""
  assert_true "ADD: file contains the LITERAL \$HOME PATH export line" \
    "grep -qF \"\$LITERAL_PATH_LINE\" \"$rc1\""
  assert_true "ADD: literal \$HOME is present (not expanded at write time)" \
    "grep -qF '\$HOME/.local/bin' \"$rc1\""

  # Behaviour 2: pre-existing content survives (block appended, not clobbering).
  assert_true "PRESERVE: pre-existing 'export FOO=1' line still present" \
    "grep -qxF 'export FOO=1' \"$rc1\""

  # ---------------------------------------------------------------------------
  # Behaviour 3: idempotent — a second call adds no duplicate block.
  # ---------------------------------------------------------------------------
  assert_true "IDEMPOTENT: second call returns success (exit 0)" \
    "ensure_path_in_rc \"$rc1\""
  assert_equals "IDEMPOTENT: start marker appears exactly once" \
    "1" \
    "$(grep -cF "$START_MARKER" "$rc1")"
  assert_equals "IDEMPOTENT: end marker appears exactly once" \
    "1" \
    "$(grep -cF "$END_MARKER" "$rc1")"
  assert_equals "IDEMPOTENT: literal PATH export appears exactly once" \
    "1" \
    "$(grep -cF "$LITERAL_PATH_LINE" "$rc1")"

  # ---------------------------------------------------------------------------
  # Behaviour 4: no-op when the marker is already present — file unchanged.
  # ---------------------------------------------------------------------------
  local rc2="${SANDBOX_ROOT}/rc-preseeded"
  {
    printf 'export BAR=2\n'
    printf '%s\n' "$START_MARKER"
    printf 'case ":$PATH:" in\n'
    printf '  *":$HOME/.local/bin:"*) ;;\n'
    printf '  *) %s ;;\n' "$LITERAL_PATH_LINE"
    printf 'esac\n'
    printf '%s\n' "$END_MARKER"
  } > "$rc2"

  local before
  before="$(cat "$rc2")"

  assert_true "NO-OP: returns success (exit 0) when marker already present" \
    "ensure_path_in_rc \"$rc2\""

  local after
  after="$(cat "$rc2")"

  assert_equals "NO-OP: file content is byte-for-byte unchanged" \
    "$before" \
    "$after"

  # ---------------------------------------------------------------------------
  # Behaviour 5: creates the file when it does not exist.
  # ---------------------------------------------------------------------------
  local rc3="${SANDBOX_ROOT}/rc-missing"

  assert_false "CREATE: target file does not exist before the call" \
    "[[ -e \"$rc3\" ]]"
  assert_true "CREATE: returns success (exit 0) when file is missing" \
    "ensure_path_in_rc \"$rc3\""
  assert_true "CREATE: file now exists after the call" \
    "[[ -f \"$rc3\" ]]"
  assert_true "CREATE: created file contains the start marker" \
    "grep -qF \"\$START_MARKER\" \"$rc3\""
  assert_true "CREATE: created file contains the literal \$HOME PATH export" \
    "grep -qF \"\$LITERAL_PATH_LINE\" \"$rc3\""
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
  if [[ ! -f "$UTILS_PATH" ]]; then
    echo "✗ ERROR: utils.sh not found at $UTILS_PATH"
    exit 1
  fi

  echo "Testing utils.sh from: $UTILS_PATH"

  SANDBOX_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/claude-ensure-path-in-rc.XXXXXX")"

  test_ensure_path_in_rc

  print_summary
}

main "$@"

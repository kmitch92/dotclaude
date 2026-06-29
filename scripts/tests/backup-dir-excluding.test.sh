#!/usr/bin/env bash

# =============================================================================
# Test Suite for backup_dir_excluding() in utils.sh
# =============================================================================
# Verifies behaviour of:
#   backup_dir_excluding <source_dir> <exclude_pattern>...
#
# Contract (mirrors backup_file naming/return convention):
#   - Creates "<source_dir>.backup.<timestamp>" and echoes that path on stdout
#     so callers can capture it.
#   - Recursively copies <source_dir> into the backup, EXCLUDING any top-level
#     entry whose name matches one of the given exclude patterns (exact names
#     like `debug`, `history.jsonl`, and globs like `*.log`).
#   - If <source_dir> does not exist: no-op (echoes nothing, returns success).
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
# Test Framework (mirrors utils.test.sh)
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

# Build a realistic source directory with a mix of KEEP and EXCLUDE entries.
# Echoes the path to the populated source directory.
make_source_dir() {
  local src="${SANDBOX_ROOT}/src"
  mkdir -p "$src"

  # KEEP items
  printf 'claude config\n' > "${src}/CLAUDE.md"
  printf '{"setting":true}\n' > "${src}/settings.json"
  mkdir -p "${src}/agents"
  printf 'agent foo\n' > "${src}/agents/foo.md"
  mkdir -p "${src}/plans"
  printf 'plan one\n' > "${src}/plans/plan-1.md"

  # EXCLUDE items
  mkdir -p "${src}/debug"
  printf 'debug data\n' > "${src}/debug/trace.txt"
  printf '{"event":"x"}\n' > "${src}/history.jsonl"
  mkdir -p "${src}/backups"
  printf 'old backup\n' > "${src}/backups/old.bak"
  printf 'log line\n' > "${src}/app.log"
  mkdir -p "${src}/cache"

  echo "$src"
}

cleanup() {
  if [[ -n "$SANDBOX_ROOT" && -d "$SANDBOX_ROOT" ]]; then
    rm -rf "$SANDBOX_ROOT"
  fi
}
trap cleanup EXIT

# =============================================================================
# Test Suite: backup_dir_excluding()
# =============================================================================

test_backup_dir_excluding() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Testing backup_dir_excluding() function"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Bash version: $BASH_VERSION"
  echo ""

  local src
  src="$(make_source_dir)"

  # Behaviour 1: creates a backup dir and echoes its path on stdout.
  local backup
  backup="$(backup_dir_excluding "$src" debug history.jsonl backups cache '*.log')"

  assert_true "echoes a non-empty backup path on stdout" \
    "[[ -n \"$backup\" ]]"
  assert_true "echoed backup path exists and is a directory" \
    "[[ -d \"$backup\" ]]"

  # Behaviour 2: KEEP items present, including nested content with correct data.
  assert_true "KEEP: CLAUDE.md present in backup" \
    "[[ -f \"${backup}/CLAUDE.md\" ]]"
  assert_equals "KEEP: CLAUDE.md content preserved" \
    "claude config" \
    "$(cat "${backup}/CLAUDE.md" 2>/dev/null)"
  assert_true "KEEP: settings.json present in backup" \
    "[[ -f \"${backup}/settings.json\" ]]"
  assert_true "KEEP: agents/ dir present in backup" \
    "[[ -d \"${backup}/agents\" ]]"
  assert_true "KEEP: nested agents/foo.md present in backup" \
    "[[ -f \"${backup}/agents/foo.md\" ]]"
  assert_equals "KEEP: nested agents/foo.md content preserved" \
    "agent foo" \
    "$(cat "${backup}/agents/foo.md" 2>/dev/null)"
  assert_true "KEEP: plans/ dir present in backup" \
    "[[ -d \"${backup}/plans\" ]]"
  assert_true "KEEP: nested plans/plan-1.md present in backup" \
    "[[ -f \"${backup}/plans/plan-1.md\" ]]"

  # Behaviour 3: each EXCLUDE item is absent from the backup.
  assert_false "EXCLUDE: debug/ absent from backup" \
    "[[ -e \"${backup}/debug\" ]]"
  assert_false "EXCLUDE: history.jsonl absent from backup" \
    "[[ -e \"${backup}/history.jsonl\" ]]"
  assert_false "EXCLUDE: backups/ absent from backup" \
    "[[ -e \"${backup}/backups\" ]]"
  assert_false "EXCLUDE: app.log (*.log glob) absent from backup" \
    "[[ -e \"${backup}/app.log\" ]]"
  assert_false "EXCLUDE: cache/ absent from backup" \
    "[[ -e \"${backup}/cache\" ]]"

  # Behaviour 4: original source dir is unchanged (all items still present).
  assert_true "ORIGINAL: CLAUDE.md still present in source" \
    "[[ -f \"${src}/CLAUDE.md\" ]]"
  assert_true "ORIGINAL: settings.json still present in source" \
    "[[ -f \"${src}/settings.json\" ]]"
  assert_true "ORIGINAL: agents/foo.md still present in source" \
    "[[ -f \"${src}/agents/foo.md\" ]]"
  assert_true "ORIGINAL: plans/plan-1.md still present in source" \
    "[[ -f \"${src}/plans/plan-1.md\" ]]"
  assert_true "ORIGINAL: excluded debug/ still present in source" \
    "[[ -d \"${src}/debug\" ]]"
  assert_true "ORIGINAL: excluded history.jsonl still present in source" \
    "[[ -f \"${src}/history.jsonl\" ]]"
  assert_true "ORIGINAL: excluded backups/ still present in source" \
    "[[ -d \"${src}/backups\" ]]"
  assert_true "ORIGINAL: excluded app.log still present in source" \
    "[[ -f \"${src}/app.log\" ]]"
  assert_true "ORIGINAL: excluded cache/ still present in source" \
    "[[ -d \"${src}/cache\" ]]"

  # Behaviour 5: missing source is a no-op — returns success, creates no backup.
  local missing="${src}/does-not-exist"
  local missing_out
  missing_out="$(backup_dir_excluding "$missing" debug)"

  assert_true "MISSING SOURCE: returns success (exit 0)" \
    "backup_dir_excluding \"$missing\" debug"
  assert_equals "MISSING SOURCE: echoes nothing" \
    "" \
    "$missing_out"
  assert_false "MISSING SOURCE: no backup directory created" \
    "compgen -G \"${missing}.backup.*\" > /dev/null"
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

  SANDBOX_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/claude-backup-dir-excluding.XXXXXX")"

  test_backup_dir_excluding

  print_summary
}

main "$@"

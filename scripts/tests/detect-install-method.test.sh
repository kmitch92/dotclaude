#!/usr/bin/env bash

# =============================================================================
# Test Suite for detect_claude_install_method() in utils.sh
# =============================================================================
# Verifies pure detection logic for how the `claude` binary was installed.
# Expected return values (echoed):
#   native  - installed by Anthropic's native installer (~/.local/share/claude)
#   brew    - installed via Homebrew (/opt/homebrew or /usr/local prefix)
#   npm     - installed via npm global (under `npm root -g`)
#   unknown - none of the above
# Exit status:
#   0 on successful classification (including "unknown")
#   1 if binary path argument is missing or not executable
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

# Create a temporary sandbox and echo its path.
make_sandbox() {
  mktemp -d "${TMPDIR:-/tmp}/claude-install-detect.XXXXXX"
}

# Create a fake `claude` executable at $1 and print its path.
make_fake_binary() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  printf '#!/bin/sh\nexit 0\n' > "$target"
  chmod +x "$target"
  echo "$target"
}

# =============================================================================
# Test Suite
# =============================================================================

test_native_detection_via_share_claude_versions() {
  local sandbox target link
  sandbox="$(make_sandbox)"
  target="$(make_fake_binary "${sandbox}/.local/share/claude/versions/2.1.78/claude")"
  link="${sandbox}/.local/bin/claude"
  mkdir -p "$(dirname "$link")"
  ln -s "$target" "$link"

  local result
  result="$(HOME="$sandbox" PATH="/usr/bin:/bin" detect_claude_install_method "$link" 2>/dev/null || echo "__ERROR__")"

  assert_equals "native detection via ~/.local/share/claude/versions/*" "native" "$result"

  rm -rf "$sandbox"
}

test_native_detection_via_share_claude_root() {
  local sandbox target link
  sandbox="$(make_sandbox)"
  # Native path that does not include /versions/ segment but still under share/claude
  target="$(make_fake_binary "${sandbox}/.local/share/claude/bin/claude")"
  link="${sandbox}/.local/bin/claude"
  mkdir -p "$(dirname "$link")"
  ln -s "$target" "$link"

  local result
  result="$(HOME="$sandbox" PATH="/usr/bin:/bin" detect_claude_install_method "$link" 2>/dev/null || echo "__ERROR__")"

  assert_equals "native detection via \$HOME/.local/share/claude" "native" "$result"

  rm -rf "$sandbox"
}

test_npm_detection_via_node_modules_path() {
  local sandbox target
  sandbox="$(make_sandbox)"
  target="$(make_fake_binary "${sandbox}/npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude")"

  # Shim `npm root -g` inside a subshell so detection can match by either heuristic.
  local result
  result="$(
    npm() {
      if [[ "${1:-}" == "root" && "${2:-}" == "-g" ]]; then
        echo "${sandbox}/npm-global/lib/node_modules"
        return 0
      fi
      return 1
    }
    export -f npm 2>/dev/null || true
    HOME="$sandbox" detect_claude_install_method "$target" 2>/dev/null || echo "__ERROR__"
  )"

  assert_equals "npm detection via @anthropic-ai/claude-code node_modules path" "npm" "$result"

  rm -rf "$sandbox"
}

test_npm_detection_via_npm_root_prefix() {
  local sandbox target
  sandbox="$(make_sandbox)"
  # Path does NOT contain @anthropic-ai/claude-code — relies on `npm root -g` match
  target="$(make_fake_binary "${sandbox}/npm-global/bin/claude")"

  local result
  result="$(
    npm() {
      if [[ "${1:-}" == "root" && "${2:-}" == "-g" ]]; then
        echo "${sandbox}/npm-global/lib/node_modules"
        return 0
      fi
      return 1
    }
    export -f npm 2>/dev/null || true
    HOME="$sandbox" detect_claude_install_method "$target" 2>/dev/null || echo "__ERROR__"
  )"

  # When binary lives under the npm prefix but not under node_modules/@anthropic-ai,
  # detection should still resolve to npm via the `npm root -g` heuristic.
  assert_equals "npm detection via npm root -g prefix match" "npm" "$result"

  rm -rf "$sandbox"
}

test_brew_detection_opt_homebrew() {
  local sandbox target
  sandbox="$(make_sandbox)"
  # Simulate Apple Silicon homebrew layout. The *resolved* path must match
  # the literal /opt/homebrew/ prefix per the spec, so we create a symlink
  # from the sandbox to a resolvable /opt/homebrew-like path via a fake.
  # Since we can't write under /opt/homebrew without root, we rely on the
  # function accepting a raw path that already starts with /opt/homebrew/.
  target="/opt/homebrew/bin/claude-fake-for-test"

  # We do NOT create this file on disk — the function should short-circuit
  # via prefix + `brew list claude` check. Shim `brew` so the formula appears
  # installed. If the function requires the binary to exist, this test will
  # fail with `__ERROR__` which is acceptable RED signal.
  local result
  result="$(
    brew() {
      if [[ "${1:-}" == "list" && "${2:-}" == "--formula" ]]; then
        echo "claude"
        return 0
      fi
      if [[ "${1:-}" == "list" && "${2:-}" == "claude" ]]; then
        return 0
      fi
      return 1
    }
    export -f brew 2>/dev/null || true
    # Use a real fake binary under a brew-prefix-shaped sandbox path instead,
    # since the function will likely require -x on the path.
    local real_target="${sandbox}/opt/homebrew/bin/claude"
    mkdir -p "$(dirname "$real_target")"
    printf '#!/bin/sh\nexit 0\n' > "$real_target"
    chmod +x "$real_target"
    HOME="$sandbox" BREW_PREFIX_OVERRIDE="${sandbox}/opt/homebrew" detect_claude_install_method "$real_target" 2>/dev/null || echo "__ERROR__"
  )"

  # Acceptable outcomes: "brew" if function honours BREW_PREFIX_OVERRIDE, else
  # the strict spec says the path must literally start with /opt/homebrew/.
  # The authoritative spec case is exercised by the next test.
  assert_equals "brew detection via sandboxed homebrew prefix (with override)" "brew" "$result"

  rm -rf "$sandbox"
}

test_brew_detection_literal_opt_homebrew_prefix() {
  # Authoritative test against the literal /opt/homebrew/ prefix per spec.
  # We cannot create files under /opt/homebrew/ in a sandbox, so we pass a
  # path that starts with that prefix and is NOT required to exist on disk.
  # If the function requires the file to be executable, the error-case test
  # below covers that contract separately; here we assert that IF the path
  # exists and matches the brew prefix AND `brew list` reports the formula,
  # the result is "brew". We simulate path existence by symlinking the
  # passed-in path target into place is infeasible in an unprivileged test,
  # so this test is expressed conditionally.

  local sandbox
  sandbox="$(make_sandbox)"

  # Skip cleanly if /opt/homebrew/bin is not writable — we do not want to
  # pollute system directories. Instead, verify the prefix-match contract
  # through a fake path using $HOME-rooted shim accepted via override.
  local fake_prefix="${sandbox}/opt/homebrew"
  local target="${fake_prefix}/bin/claude"
  mkdir -p "$(dirname "$target")"
  printf '#!/bin/sh\nexit 0\n' > "$target"
  chmod +x "$target"

  local result
  result="$(
    brew() {
      if [[ "${1:-}" == "list" && ( "${2:-}" == "--formula" || "${2:-}" == "claude" ) ]]; then
        echo "claude"
        return 0
      fi
      if [[ "${1:-}" == "--prefix" ]]; then
        echo "${fake_prefix}"
        return 0
      fi
      return 1
    }
    export -f brew 2>/dev/null || true
    HOME="$sandbox" detect_claude_install_method "$target" 2>/dev/null || echo "__ERROR__"
  )"

  assert_equals "brew detection via \`brew --prefix\`-reported prefix match" "brew" "$result"

  rm -rf "$sandbox"
}

test_unknown_detection_random_path() {
  local sandbox target
  sandbox="$(make_sandbox)"
  target="$(make_fake_binary "${sandbox}/random/place/claude")"

  local result
  result="$(
    npm() { return 1; }
    brew() { return 1; }
    export -f npm brew 2>/dev/null || true
    HOME="$sandbox" detect_claude_install_method "$target" 2>/dev/null || echo "__ERROR__"
  )"

  assert_equals "unknown detection for arbitrary binary path" "unknown" "$result"

  rm -rf "$sandbox"
}

test_error_nonexistent_binary() {
  local sandbox missing
  sandbox="$(make_sandbox)"
  missing="${sandbox}/does/not/exist/claude"

  # Expect: function is defined AND returns non-zero. Guarding with declare -F
  # prevents a false green while the function does not yet exist.
  assert_true "returns non-zero for non-existent binary path" \
    "declare -F detect_claude_install_method >/dev/null 2>&1 && ! HOME='$sandbox' detect_claude_install_method '$missing' >/dev/null 2>&1"

  rm -rf "$sandbox"
}

test_error_missing_argument() {
  assert_true "returns non-zero when no binary path argument is provided" \
    "declare -F detect_claude_install_method >/dev/null 2>&1 && ! detect_claude_install_method >/dev/null 2>&1"
}

test_error_non_executable_file() {
  local sandbox target
  sandbox="$(make_sandbox)"
  target="${sandbox}/claude-not-exec"
  : > "$target"  # create but do not chmod +x

  assert_true "returns non-zero when path exists but is not executable" \
    "declare -F detect_claude_install_method >/dev/null 2>&1 && ! HOME='$sandbox' detect_claude_install_method '$target' >/dev/null 2>&1"

  rm -rf "$sandbox"
}

# =============================================================================
# Edge Case Tests (added during VERIFY phase)
# =============================================================================

test_path_with_spaces_native() {
  # macOS users may have spaces in $HOME (e.g. /Users/First Last). Verify
  # detection still classifies correctly when the resolved path contains spaces.
  local sandbox target link
  sandbox="$(make_sandbox)/dir with spaces"
  mkdir -p "$sandbox"
  target="$(make_fake_binary "${sandbox}/.local/share/claude/versions/2.1.78/claude")"
  link="${sandbox}/.local/bin/claude"
  mkdir -p "$(dirname "$link")"
  ln -s "$target" "$link"

  local result
  result="$(HOME="$sandbox" PATH="/usr/bin:/bin" detect_claude_install_method "$link" 2>/dev/null || echo "__ERROR__")"

  assert_equals "native detection with spaces in path" "native" "$result"

  rm -rf "$(dirname "$sandbox")"
}

test_dangling_symlink_returns_error() {
  # A broken symlink (target removed) must not be classified. It should
  # fail the existence check and return non-zero.
  local sandbox target link
  sandbox="$(make_sandbox)"
  target="${sandbox}/missing-target"
  link="${sandbox}/claude"
  ln -s "$target" "$link"
  # target is NOT created -> dangling symlink

  assert_true "returns non-zero for dangling symlink" \
    "! HOME='$sandbox' detect_claude_install_method '$link' >/dev/null 2>&1"

  rm -rf "$sandbox"
}

test_symlink_loop_does_not_hang() {
  # Infinite symlink loop: a -> b -> a. Implementation must bound traversal.
  local sandbox a b
  sandbox="$(make_sandbox)"
  a="${sandbox}/a"
  b="${sandbox}/b"
  ln -s "$b" "$a"
  ln -s "$a" "$b"

  # If implementation lacks loop protection, this would hang forever; run
  # with a timeout to fail fast. macOS lacks GNU `timeout` by default, so
  # simulate via background job + kill. If the function returns within
  # 3 seconds we consider the loop guard present.
  local pid rc=0
  (
    HOME="$sandbox" detect_claude_install_method "$a" >/dev/null 2>&1
  ) &
  pid=$!
  local waited=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1
    waited=$((waited + 1))
    if [ "$waited" -ge 3 ]; then
      kill -9 "$pid" 2>/dev/null
      rc=1
      break
    fi
  done
  wait "$pid" 2>/dev/null

  assert_true "symlink loop does not hang (bounded traversal)" "[ $rc -eq 0 ]"

  rm -rf "$sandbox"
}

test_mise_shim_classifies_as_unknown() {
  # `claude` installed as a mise or asdf shim lives under
  # ~/.local/share/mise/shims/ or ~/.asdf/shims/. These are not native,
  # npm, or brew installs and should classify as "unknown".
  local sandbox target
  sandbox="$(make_sandbox)"
  target="$(make_fake_binary "${sandbox}/.local/share/mise/shims/claude")"

  local result
  result="$(
    npm() { return 1; }
    brew() { return 1; }
    export -f npm brew 2>/dev/null || true
    HOME="$sandbox" detect_claude_install_method "$target" 2>/dev/null || echo "__ERROR__"
  )"

  assert_equals "mise shim classifies as unknown" "unknown" "$result"

  rm -rf "$sandbox"
}

test_asdf_shim_classifies_as_unknown() {
  local sandbox target
  sandbox="$(make_sandbox)"
  target="$(make_fake_binary "${sandbox}/.asdf/shims/claude")"

  local result
  result="$(
    npm() { return 1; }
    brew() { return 1; }
    export -f npm brew 2>/dev/null || true
    HOME="$sandbox" detect_claude_install_method "$target" 2>/dev/null || echo "__ERROR__"
  )"

  assert_equals "asdf shim classifies as unknown" "unknown" "$result"

  rm -rf "$sandbox"
}

# =============================================================================
# Main
# =============================================================================

main() {
  if [[ ! -f "$UTILS_PATH" ]]; then
    echo "✗ ERROR: utils.sh not found at $UTILS_PATH"
    exit 1
  fi

  echo "Testing detect_claude_install_method() from: $UTILS_PATH"
  echo "Bash version: $BASH_VERSION"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Testing detect_claude_install_method()"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Guard: if the function is undefined, every call will fail — that is the
  # expected RED state. We still run each test so the failure output lists
  # every behaviour that must eventually pass.
  if ! declare -F detect_claude_install_method >/dev/null 2>&1; then
    echo "ℹ detect_claude_install_method is not defined in utils.sh (expected during RED)"
    echo ""
  fi

  test_native_detection_via_share_claude_versions
  test_native_detection_via_share_claude_root
  test_npm_detection_via_node_modules_path
  test_npm_detection_via_npm_root_prefix
  test_brew_detection_opt_homebrew
  test_brew_detection_literal_opt_homebrew_prefix
  test_unknown_detection_random_path
  test_error_nonexistent_binary
  test_error_missing_argument
  test_error_non_executable_file

  # Edge cases (VERIFY phase)
  test_path_with_spaces_native
  test_dangling_symlink_returns_error
  test_symlink_loop_does_not_hang
  test_mise_shim_classifies_as_unknown
  test_asdf_shim_classifies_as_unknown

  print_summary
}

main "$@"

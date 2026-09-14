#!/usr/bin/env bash
# Behavioral tests for setup-mcp.sh (registers MCP servers with the claude CLI).
#
# Contract: render mcp/mcp.json.template with envsubst using .env.mcp.local,
# then for each rendered server run
#   claude mcp remove --scope user <name>          (failure ignored)
#   claude mcp add-json --scope user <name> '<json>'
# where <json> equals that server's rendered object. context7 is skipped when
# CONTEXT7_API_KEY is empty or the placeholder. ~/.mcp.json is never created or
# modified. Without the claude CLI on PATH: non-zero exit, "claude CLI not found".
#
# Stubbed env: each case runs a COPY of scripts/ and mcp/ in a throwaway repo
# dir with a fixture .env.mcp.local, so no real repo file is touched. HOME is a
# throwaway dir. A stub `claude` (first on PATH) logs each call as one JSON
# array line of its argv; stub npx/uvx satisfy the runtime-tools check. Any PATH
# dir holding the real `claude` is stripped. Real jq and envsubst are used.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_REPO="$(cd "$TEST_DIR/../.." && pwd)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/setup-mcp-test.XXXXXX")"
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

REAL_KEY="ctx7-real-key-123"
HOME_DIR=""; REPO=""; BINDIR=""; CLAUDE_LOG=""; RC=0; OUTPUT=""

write_claude_stub() {
  local remove_rc="$1"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'LOG=%q\nJQ=%q\nREMOVE_RC=%q\n' "$CLAUDE_LOG" "$JQ_BIN" "$remove_rc"
    cat <<'STUB'
parts=()
for a in "$@"; do
  parts+=("$(printf '%s' "$a" | "$JQ" -Rs .)")
done
( IFS=,; printf '[%s]\n' "${parts[*]}" ) >> "$LOG"
if [ "${1:-}" = "mcp" ] && [ "${2:-}" = "remove" ]; then
  exit "$REMOVE_RC"
fi
exit 0
STUB
  } > "$BINDIR/claude"
  chmod +x "$BINDIR/claude"
}

write_ok_stub() {
  printf '#!/usr/bin/env bash\nexit 0\n' > "$BINDIR/$1"
  chmod +x "$BINDIR/$1"
}

setup_env() {
  local key="$1" with_claude="${2:-with-claude}"
  HOME_DIR="$(mktemp -d "$WORK/home.XXXXXX")"
  REPO="$(mktemp -d "$WORK/repo.XXXXXX")"
  BINDIR="$(mktemp -d "$WORK/bin.XXXXXX")"
  CLAUDE_LOG="$WORK/$(basename "$BINDIR").claude-calls.log"
  cp -R "$SRC_REPO/scripts" "$SRC_REPO/mcp" "$REPO/"
  printf 'CONTEXT7_API_KEY="%s"\n' "$key" > "$REPO/.env.mcp.local"
  write_ok_stub npx
  write_ok_stub uvx
  if [ "$with_claude" = "with-claude" ]; then
    write_claude_stub 0
  fi
}

run_setup() {
  HOME="$HOME_DIR" PATH="$BINDIR:$SAFE_PATH" timeout 120 bash "$REPO/scripts/setup-mcp.sh" </dev/null >"$WORK/output" 2>&1
  RC=$?
  OUTPUT="$(cat "$WORK/output")"
}

rendered_template() {
  (
    set -a
    . "$REPO/.env.mcp.local"
    set +a
    HOME="$HOME_DIR" envsubst < "$REPO/mcp/mcp.json.template"
  )
}

template_server_names() {
  "$JQ_BIN" -r '.mcpServers | keys[]' "$REPO/mcp/mcp.json.template" | sort | tr '\n' ' '
}

template_server_names_except() {
  "$JQ_BIN" -r --arg skip "$1" '.mcpServers | keys[] | select(. != $skip)' "$REPO/mcp/mcp.json.template" | sort | tr '\n' ' '
}

added_server_names() {
  [ -f "$CLAUDE_LOG" ] || return 0
  "$JQ_BIN" -r 'select(.[0] == "mcp" and .[1] == "add-json") | .[4] // empty' "$CLAUDE_LOG" | sort | tr '\n' ' '
}

add_json_count_for() {
  [ -f "$CLAUDE_LOG" ] || { echo 0; return 0; }
  "$JQ_BIN" -s --arg n "$1" '[.[] | select(.[0] == "mcp" and .[1] == "add-json" and .[4] == $n)] | length' "$CLAUDE_LOG"
}

add_json_payload_for() {
  [ -f "$CLAUDE_LOG" ] || return 0
  "$JQ_BIN" -r --arg n "$1" 'select(.[0] == "mcp" and .[1] == "add-json" and .[4] == $n) | .[5] // empty' "$CLAUDE_LOG"
}

echo "== registers every template server via claude mcp add-json --scope user =="
setup_env "$REAL_KEY"
run_setup
assert_eq "$RC" "0" "register: exits 0"
EXPECTED_NAMES="$(template_server_names)"
assert_ne "$EXPECTED_NAMES" "" "register: fixture template lists servers"
assert_eq "$(added_server_names)" "$EXPECTED_NAMES" "register: add-json called for every rendered server"
SHAPE_OK="$([ -f "$CLAUDE_LOG" ] && "$JQ_BIN" -s '[.[] | select(.[0] == "mcp" and .[1] == "add-json")] | length > 0 and all(length == 6 and .[2] == "--scope" and .[3] == "user")' "$CLAUDE_LOG" || echo false)"
assert_eq "$SHAPE_OK" "true" "register: every call is exactly: claude mcp add-json --scope user <name> <json>"
for name in $EXPECTED_NAMES; do
  assert_eq "$(add_json_count_for "$name")" "1" "register: add-json called exactly once for $name"
done

echo "== add-json payload is valid JSON equal to the rendered template entry =="
setup_env "$REAL_KEY"
run_setup
RENDERED="$(rendered_template)"
for name in $(template_server_names); do
  PAYLOAD="$(add_json_payload_for "$name")"
  if [ -n "$PAYLOAD" ] && printf '%s' "$PAYLOAD" | "$JQ_BIN" -e . >/dev/null 2>&1; then
    pass "payload: $name argument is valid JSON"
  else
    fail "payload: $name argument is valid JSON (got [$PAYLOAD])"
  fi
  EXPECTED_SERVER="$(printf '%s' "$RENDERED" | "$JQ_BIN" -c --arg n "$name" '.mcpServers[$n]')"
  SAME="$("$JQ_BIN" -n --argjson a "${PAYLOAD:-null}" --argjson b "$EXPECTED_SERVER" '$a == $b' 2>/dev/null || echo false)"
  assert_eq "$SAME" "true" "payload: $name equals its rendered template object"
  assert_not_contains "$PAYLOAD" '${' "payload: $name has no unsubstituted \${VAR}"
done
assert_contains "$(add_json_payload_for context7)" "$REAL_KEY" "payload: context7 carries the API key from .env.mcp.local"

echo "== each server is removed from user scope before it is added =="
setup_env "$REAL_KEY"
run_setup
for name in $(template_server_names); do
  ORDER_OK="$([ -f "$CLAUDE_LOG" ] && "$JQ_BIN" -s --arg n "$name" '
    ([to_entries[] | select(.value == ["mcp", "remove", "--scope", "user", $n]) | .key] | first) as $r
    | ([to_entries[] | select(.value[0:5] == ["mcp", "add-json", "--scope", "user", $n]) | .key] | first) as $a
    | ($r != null and $a != null and $r < $a)' "$CLAUDE_LOG" || echo false)"
  assert_eq "$ORDER_OK" "true" "remove-first: claude mcp remove --scope user $name precedes its add-json"
done

echo "== a failing remove does not stop registration =="
setup_env "$REAL_KEY"
write_claude_stub 1
run_setup
assert_eq "$RC" "0" "remove fails: exits 0"
assert_eq "$(added_server_names)" "$(template_server_names)" "remove fails: every server still added"

echo "== context7 is skipped when CONTEXT7_API_KEY is empty =="
setup_env ""
run_setup
assert_eq "$RC" "0" "empty key: exits 0"
assert_eq "$(add_json_count_for context7)" "0" "empty key: no add-json for context7"
assert_ne "$(template_server_names_except context7)" "" "empty key: template has servers besides context7"
assert_eq "$(added_server_names)" "$(template_server_names_except context7)" "empty key: all other servers added"

echo "== context7 is skipped when CONTEXT7_API_KEY is the placeholder =="
setup_env "your_api_key_here"
run_setup
assert_eq "$RC" "0" "placeholder key: exits 0"
assert_eq "$(add_json_count_for context7)" "0" "placeholder key: no add-json for context7"
assert_eq "$(added_server_names)" "$(template_server_names_except context7)" "placeholder key: all other servers added"

echo "== ~/.mcp.json is never created =="
setup_env "$REAL_KEY"
run_setup
assert_absent "$HOME_DIR/.mcp.json" "no-create: \$HOME/.mcp.json does not exist after setup"

echo "== an existing ~/.mcp.json file is left untouched =="
setup_env "$REAL_KEY"
printf '{"sentinel": "keep-me"}\n' > "$HOME_DIR/.mcp.json"
cp "$HOME_DIR/.mcp.json" "$WORK/mcp-json-before"
run_setup
if [ -f "$HOME_DIR/.mcp.json" ] && cmp -s "$HOME_DIR/.mcp.json" "$WORK/mcp-json-before"; then
  pass "no-modify: existing \$HOME/.mcp.json is byte-identical"
else
  fail "no-modify: existing \$HOME/.mcp.json is byte-identical (changed or removed)"
fi

echo "== an existing ~/.mcp.json symlink is left untouched =="
setup_env "$REAL_KEY"
LINK_TARGET="$WORK/$(basename "$HOME_DIR").linked-mcp.json"
printf '{"sentinel": "linked"}\n' > "$LINK_TARGET"
ln -s "$LINK_TARGET" "$HOME_DIR/.mcp.json"
run_setup
assert_eq "$(readlink "$HOME_DIR/.mcp.json" 2>/dev/null || true)" "$LINK_TARGET" "no-modify: \$HOME/.mcp.json symlink still points at its target"
assert_eq "$(cat "$LINK_TARGET")" '{"sentinel": "linked"}' "no-modify: symlink target content unchanged"

echo "== missing claude CLI fails with a clear message =="
setup_env "$REAL_KEY" "without-claude"
run_setup
assert_ne "$RC" "0" "no claude: exits non-zero"
assert_contains "$OUTPUT" "claude CLI not found" "no claude: output says claude CLI not found"
assert_absent "$HOME_DIR/.mcp.json" "no claude: \$HOME/.mcp.json not created"

echo
echo "== summary: $pass_count passed, $fail_count failed =="
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0

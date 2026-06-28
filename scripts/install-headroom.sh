#!/usr/bin/env bash

# =============================================================================
# Headroom Proxy Installation / Setup
# =============================================================================
# Installs the Headroom CLI and ensures the persistent proxy service is running.
#
# Routing note:
#   Claude Code is pointed at the proxy via ANTHROPIC_BASE_URL set in
#   ~/dotclaude/claude/.claude/settings.json (the `env` block), NOT via a shell
#   wrapper or an exported var in ~/.zshrc. This keeps all agentic-AI config
#   inside the dotclaude repo and avoids any crossover into dotfiles/shell
#   config. Because of that, this script also strips any shell-rc block that
#   `headroom install apply` may inject, so the dev shell stays untouched.
#
# Idempotent: safe to run repeatedly.
#
# Usage: ./scripts/install-headroom.sh
# =============================================================================

set -euo pipefail

# Get the directory where this script's parent (dotclaude) is located
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source utilities (print_*, command_exists, is_macos, etc.)
source "$DOTFILES_DIR/scripts/utils.sh"

readonly HEADROOM_PORT="${HEADROOM_PORT:-8787}"
readonly HEADROOM_HEALTH_URL="http://127.0.0.1:${HEADROOM_PORT}/health"

# Gitignored Claude settings override (takes precedence over settings.json).
# Used by the routing fail-safe below to force Claude Code direct to Anthropic
# when the proxy is unhealthy, then clear that override once it recovers.
readonly SETTINGS_LOCAL="$DOTFILES_DIR/claude/.claude/settings.local.json"
readonly ANTHROPIC_DIRECT_URL="https://api.anthropic.com"

print_header "Setting up Headroom Proxy"

# =============================================================================
# Prerequisite: uv (handled elsewhere)
# =============================================================================

if ! command_exists uv; then
  print_warning "uv not found — it is a prerequisite for installing Headroom"
  print_info "Install uv first (handled by a separate setup step), then re-run this script"
  print_info "  See: https://docs.astral.sh/uv/getting-started/installation/"
  exit 0
fi

# =============================================================================
# Install the Headroom CLI
# =============================================================================

if command_exists headroom; then
  print_success "Headroom CLI already installed: $(headroom --version 2>/dev/null || echo 'unknown')"
else
  print_info "Installing Headroom CLI via uv..."
  uv tool install "headroom-ai[all]"
  print_success "Headroom CLI installed"
fi

# =============================================================================
# Detect a flag that avoids editing shell rc files
# =============================================================================
# Prefer a native "don't touch my shell / don't wire tools" flag if one exists,
# so we never have to clean up ~/.zshrc afterwards. As of headroom 0.26.0 no
# such --no-shell/--no-wire flag exists; the closest control is
# `--providers manual` (configures no tool targets unless --target is given).
# We probe the help output so this stays correct if a future version adds one.

NO_SHELL_FLAG=""
apply_help="$(headroom install apply --help 2>&1 || true)"
install_help="$(headroom install --help 2>&1 || true)"
combined_help="${apply_help}
${install_help}"

for candidate in --no-shell --no-wire --no-rc --no-shell-init --skip-shell --no-profile; do
  if printf '%s\n' "$combined_help" | grep -q -- "$candidate"; then
    NO_SHELL_FLAG="$candidate"
    break
  fi
done

if [ -n "$NO_SHELL_FLAG" ]; then
  print_info "Using '$NO_SHELL_FLAG' to avoid editing shell rc files"
else
  print_info "No no-shell flag available in this Headroom version"
  print_info "Will clean up any injected shell-rc block after apply"
fi

# =============================================================================
# Work around a launchctl bootout/bootstrap race in `headroom install apply`
# =============================================================================
# On macOS, `headroom install apply` runs `launchctl bootout <domain>` (async,
# unchecked) immediately followed by `launchctl bootstrap`. bootout returns
# before the kernel finishes unloading the job, so bootstrap finds the old job
# still registered and exits 5 (EIO). We cannot patch the vendored python (it is
# overwritten on every `uv tool install`), so we tear the job down ourselves and
# wait for it to fully disappear BEFORE calling apply — making apply's own
# bootout a no-op and removing the race.

teardown_launchd_and_wait() {
  local domain="gui/$(id -u)/com.headroom.default"

  # Unload the job if present. It may not be loaded — that is fine, so we ignore
  # the exit status entirely.
  launchctl bootout "$domain" >/dev/null 2>&1 || true

  # Poll until the job is fully gone (print returns non-zero) or we time out.
  # ~10s budget: 20 iterations of 0.5s.
  local i
  for i in $(seq 1 20); do
    if ! launchctl print "$domain" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done

  print_info "launchd job '$domain' still present after teardown wait; continuing"
  return 0
}

# =============================================================================
# Ensure the persistent proxy is running
# =============================================================================

is_proxy_running() {
  # Require BOTH running AND healthy. A loaded-but-unhealthy proxy must NOT be
  # treated as fine — returning 1 here lets it fall through to the safe
  # teardown -> apply recovery path. Capture status once and check both lines.
  local status
  status="$(headroom install status 2>/dev/null || true)"

  printf '%s\n' "$status" | grep -qiE '^Status:[[:space:]]+running' || return 1
  printf '%s\n' "$status" | grep -qiE '^Healthy:[[:space:]]+yes' || return 1
  return 0
}

# Tear down any existing launchd job, then apply the persistent-service preset
# with a single retry-after-full-teardown. Used both for the initial install and
# as the repair step before the direct-routing fallback. Returns 1 on terminal
# failure so callers decide what to do (the caller, not this function, owns the
# exit/skip/fallback policy).
establish_proxy() {
  local apply_cmd=(headroom install apply --preset persistent-service --providers auto)
  if [ -n "$NO_SHELL_FLAG" ]; then
    apply_cmd+=("$NO_SHELL_FLAG")
  fi

  # Pre-empt the launchctl race: tear down any existing job and wait for it to
  # fully unload so apply's internal bootout is a no-op and its bootstrap can't
  # collide with a still-registered job.
  teardown_launchd_and_wait

  # Resilient apply: `set -e` is suppressed inside `if` conditions, so a single
  # failure no longer aborts the whole install. On failure we do a full teardown
  # and retry once; if it still fails we return 1 and let the caller decide.
  if ! "${apply_cmd[@]}"; then
    print_warning "Headroom apply failed (likely a launchctl bootstrap race); retrying after full teardown..."
    teardown_launchd_and_wait
    if ! "${apply_cmd[@]}"; then
      return 1
    fi
  fi
  print_success "Headroom proxy service applied"
  return 0
}

if is_proxy_running; then
  print_success "Headroom proxy already running (persistent service)"
else
  print_info "Installing persistent Headroom proxy service..."
  if ! establish_proxy; then
    print_warning "Headroom proxy could not be installed; skipping (proxy is optional)."
    print_info "Re-run later with: bash scripts/install-headroom.sh"
    exit 0
  fi
fi

# =============================================================================
# Clean up any shell-rc block Headroom may have injected
# =============================================================================
# Routing is handled by Claude Code's settings.json (ANTHROPIC_BASE_URL), so we
# strip anything Headroom wrote into the shell rc to keep dotfiles/shell config
# untouched. No-op if nothing was injected. Only run when no no-shell flag was
# used (otherwise nothing should have been written).

cleanup_shell_rc() {
  local rc="$1"

  [ -f "$rc" ] || return 0

  # Resolve symlinks so we edit the real file (e.g. ~/.zshrc -> dotfiles/...).
  # NOTE: we still only edit it to *remove* Headroom-injected lines; we never
  # add anything to shell config.
  local resolved="$rc"
  while [ -L "$resolved" ]; do
    local target
    target="$(readlink "$resolved")"
    case "$target" in
      /*) resolved="$target" ;;
      *)  resolved="$(cd "$(dirname "$resolved")" && pwd)/$target" ;;
    esac
  done
  [ -f "$resolved" ] || return 0

  # Bail early if there is nothing Headroom-related to remove.
  if ! grep -qiE 'headroom|ANTHROPIC_BASE_URL' "$resolved" 2>/dev/null; then
    return 0
  fi

  print_warning "Found Headroom-injected lines in $resolved — removing"
  backup_file "$resolved" >/dev/null

  local tmp
  tmp="$(mktemp)"

  # 1. Strip the fenced `# >>> headroom ... <<<` managed block.
  # 2. Strip standalone ANTHROPIC_BASE_URL exports and `source ...headroom...`
  #    lines that may sit outside the fence.
  awk '
    /^[[:space:]]*#[[:space:]]*>>>[[:space:]]*headroom/ { skip=1; next }
    skip && /^[[:space:]]*#[[:space:]]*<<<[[:space:]]*headroom/ { skip=0; next }
    skip { next }
    /ANTHROPIC_BASE_URL/ { next }
    /source[[:space:]].*headroom/ { next }
    /^[[:space:]]*(export[[:space:]]+)?HEADROOM/ { next }
    { print }
  ' "$resolved" > "$tmp"

  if ! cmp -s "$resolved" "$tmp"; then
    cat "$tmp" > "$resolved"
    print_success "Cleaned Headroom lines from $resolved"
    print_info "Routing is handled by Claude settings.json, not the shell"
  else
    print_info "No Headroom lines needed removal from $resolved"
  fi

  rm -f "$tmp"
}

if [ -z "$NO_SHELL_FLAG" ]; then
  for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    cleanup_shell_rc "$rc"
  done
fi

# =============================================================================
# Routing fail-safe: keep Claude Code working when the proxy is down
# =============================================================================
# settings.local.json (gitignored) overrides settings.json. When the proxy is
# healthy we clear any override so the proxy URL from settings.json wins; when
# it is unhealthy we write ANTHROPIC_BASE_URL pointing direct at Anthropic so
# Claude Code keeps working instead of routing into a dead proxy.
#
# Both helpers are best-effort: if neither jq nor python3 is available they warn
# and return 0 (never fail the install). All writes go via a temp file + atomic
# mv, back up an existing file first, and only write back when content changed.

# Read current settings.local.json content, defaulting to "{}" when absent.
_read_settings_local() {
  if [ -f "$SETTINGS_LOCAL" ]; then
    cat "$SETTINGS_LOCAL"
  else
    printf '%s' '{}'
  fi
}

# Atomically write $1 to settings.local.json, but only if it differs from the
# current content. Backs up an existing file first. Returns 0 on no-op too.
_write_settings_local_if_changed() {
  local new_content="$1"
  local tmp
  tmp="$(mktemp)"
  printf '%s\n' "$new_content" > "$tmp"

  if [ -f "$SETTINGS_LOCAL" ] && cmp -s "$SETTINGS_LOCAL" "$tmp"; then
    rm -f "$tmp"
    return 1  # unchanged
  fi

  [ -f "$SETTINGS_LOCAL" ] && backup_file "$SETTINGS_LOCAL" >/dev/null
  mkdir -p "$(dirname "$SETTINGS_LOCAL")"
  mv "$tmp" "$SETTINGS_LOCAL"
  return 0  # changed
}

# Proxy IS healthy: remove any fail-safe override so settings.json wins.
enable_proxy_routing() {
  local current new
  current="$(_read_settings_local)"

  if command_exists jq; then
    # NOTE: use `(.env|type) == "object"` rather than `(.env|objects)` as the
    # `if` condition: `.env|objects` yields an *empty stream* when .env is
    # absent, and `if <empty> then..` emits nothing (would blank the file).
    # `type` always yields a value, so the env-absent case correctly no-ops.
    new="$(printf '%s' "$current" | jq 'if ((.env|type) == "object") then .env |= del(.ANTHROPIC_BASE_URL) else . end | if (.env == {}) then del(.env) else . end')"
  elif command_exists python3; then
    new="$(printf '%s' "$current" | python3 -c '
import json, sys
data = json.load(sys.stdin)
env = data.get("env")
if isinstance(env, dict):
    env.pop("ANTHROPIC_BASE_URL", None)
    if env == {}:
        data.pop("env", None)
print(json.dumps(data, indent=2))
')"
  else
    print_warning "Neither jq nor python3 available; skipping proxy-routing cleanup"
    return 0
  fi

  if _write_settings_local_if_changed "$new"; then
    print_info "Cleared proxy-routing fail-safe override from settings.local.json"
  fi
}

# Proxy is NOT healthy: write an override routing Claude Code direct to
# Anthropic, merging into (not clobbering) any existing keys.
disable_proxy_routing() {
  local current new
  current="$(_read_settings_local)"

  if command_exists jq; then
    new="$(printf '%s' "$current" | jq --arg url "$ANTHROPIC_DIRECT_URL" '.env = ((.env // {}) + {ANTHROPIC_BASE_URL: $url})')"
  elif command_exists python3; then
    new="$(printf '%s' "$current" | ANTHROPIC_DIRECT_URL="$ANTHROPIC_DIRECT_URL" python3 -c '
import json, os, sys
data = json.load(sys.stdin)
env = data.get("env")
if not isinstance(env, dict):
    env = {}
env["ANTHROPIC_BASE_URL"] = os.environ["ANTHROPIC_DIRECT_URL"]
data["env"] = env
print(json.dumps(data, indent=2))
')"
  else
    print_warning "Neither jq nor python3 available; cannot write proxy-routing fail-safe"
    return 0
  fi

  if _write_settings_local_if_changed "$new"; then
    print_warning "Proxy unhealthy — wrote ANTHROPIC_BASE_URL=$ANTHROPIC_DIRECT_URL into settings.local.json"
    print_info "Claude Code will route direct to Anthropic so it keeps working"
    print_info "Re-run this script once the proxy is fixed to restore proxy routing"
  fi
}

# =============================================================================
# Verify the proxy health endpoint
# =============================================================================

# Single source of truth for the health probe so the initial check and the
# post-repair re-check stay identical.
proxy_health_ok() {
  curl -sf -m 2 "$HEADROOM_HEALTH_URL" >/dev/null 2>&1
}

print_info "Checking proxy health: $HEADROOM_HEALTH_URL"

if proxy_health_ok; then
  print_success "Headroom proxy is healthy on port $HEADROOM_PORT"
  print_info "Claude Code routes through it via ANTHROPIC_BASE_URL in settings.json"
  enable_proxy_routing
else
  print_warning "Headroom proxy health check failed at $HEADROOM_HEALTH_URL"
  print_info "Attempting teardown and re-establish before falling back to direct routing..."

  # Repair runs AT MOST ONCE: a single establish_proxy attempt (itself limited to
  # two apply tries) followed by one re-check. No loop — if it is still unhealthy
  # we fall back to direct routing so Claude Code keeps working.
  if establish_proxy && proxy_health_ok; then
    print_success "Headroom proxy re-established and healthy on port $HEADROOM_PORT"
    print_info "Claude Code routes through it via ANTHROPIC_BASE_URL in settings.json"
    enable_proxy_routing
  else
    print_warning "Proxy still unhealthy after re-establish; falling back to direct routing"
    print_info "Check status with: headroom install status"
    print_info "Check logs / restart with: headroom install restart"
    disable_proxy_routing
  fi
fi

echo ""
print_success "Headroom setup complete!"

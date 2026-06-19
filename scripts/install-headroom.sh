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
# Ensure the persistent proxy is running
# =============================================================================

is_proxy_running() {
  headroom install status 2>/dev/null | grep -qiE '^Status:[[:space:]]+running'
}

if is_proxy_running; then
  print_success "Headroom proxy already running (persistent service)"
else
  print_info "Installing persistent Headroom proxy service..."
  apply_cmd=(headroom install apply --preset persistent-service --providers auto)
  if [ -n "$NO_SHELL_FLAG" ]; then
    apply_cmd+=("$NO_SHELL_FLAG")
  fi
  "${apply_cmd[@]}"
  print_success "Headroom proxy service applied"
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
# Verify the proxy health endpoint
# =============================================================================

print_info "Checking proxy health: $HEADROOM_HEALTH_URL"

if curl -sf -m 2 "$HEADROOM_HEALTH_URL" >/dev/null 2>&1; then
  print_success "Headroom proxy is healthy on port $HEADROOM_PORT"
  print_info "Claude Code routes through it via ANTHROPIC_BASE_URL in settings.json"
else
  print_warning "Headroom proxy health check failed at $HEADROOM_HEALTH_URL"
  print_info "Check status with: headroom install status"
  print_info "Check logs / restart with: headroom install restart"
fi

echo ""
print_success "Headroom setup complete!"

#!/usr/bin/env bash

# =============================================================================
# claude-mem Installation / Setup
# =============================================================================
# Reproduces the claude-mem plugin + settings on a fresh machine from dotclaude.
#
# What this does (idempotent, safe to re-run):
#   1. Deploys ~/.claude-mem/settings.json from the VC'd template, merging
#      without clobbering existing user values (provider/model/auth/runtime).
#      The folder-CLAUDE.md safeguard is ALWAYS forced off.
#   2. Adds the `thedotmack/claude-mem` plugin marketplace (if not present).
#   3. Installs the `claude-mem` plugin at user scope (if not present).
#
# Runtime note:
#   The plugin route uses the `claude` CLI + its bundled bun runtime. The
#   bun-based memory worker auto-starts on the first Claude Code session, so a
#   system node>=20 is NOT required for this path. No worker is started here.
#
# Prerequisite:
#   The `claude` CLI must already be installed (handled by install-claude-code.sh
#   / the native installer). If absent, this script warns and exits 0.
#
# Usage: ./scripts/install-claude-mem.sh
# =============================================================================

set -euo pipefail

# Get the directory where this script's parent (dotclaude) is located
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source utilities (print_*, command_exists, is_macos, etc.)
source "$DOTFILES_DIR/scripts/utils.sh"

readonly CLAUDE_MEM_DIR="$HOME/.claude-mem"
readonly CLAUDE_MEM_SETTINGS="$CLAUDE_MEM_DIR/settings.json"
readonly SETTINGS_TEMPLATE="$DOTFILES_DIR/claude-mem/settings.template.json"

# Marketplace source repo and plugin identifiers
readonly MARKETPLACE_REPO="thedotmack/claude-mem"
readonly PLUGIN_NAME="claude-mem"
readonly MARKETPLACE_NAME="thedotmack"

print_header "Setting up claude-mem"

# =============================================================================
# Prerequisite: the claude CLI (handled elsewhere)
# =============================================================================

if ! command_exists claude; then
  print_warning "claude CLI not found — it is a prerequisite for claude-mem"
  print_info "Install Claude Code first (scripts/install-claude-code.sh), then re-run"
  exit 0
fi

# =============================================================================
# Deploy ~/.claude-mem/settings.json (merge, no clobber)
# =============================================================================

if ! command_exists jq; then
  print_error "jq is required to merge claude-mem settings but was not found"
  print_info "Install jq (brew install jq / apt-get install jq) and re-run"
  exit 1
fi

if [ ! -f "$SETTINGS_TEMPLATE" ]; then
  print_error "Settings template not found: $SETTINGS_TEMPLATE"
  exit 1
fi

ensure_directory "$CLAUDE_MEM_DIR"

if [ ! -f "$CLAUDE_MEM_SETTINGS" ]; then
  print_info "No existing settings — deploying from template"
  cp "$SETTINGS_TEMPLATE" "$CLAUDE_MEM_SETTINGS"
  print_success "Deployed $CLAUDE_MEM_SETTINGS"
else
  print_info "Existing settings found — merging (preserving user values)"

  # Merge semantics:
  #   - Start from the template (provides any missing keys).
  #   - Overlay the existing user settings on top (existing values for
  #     runtime/provider/auth/model WIN over template defaults).
  #   - Finally force the folder-CLAUDE.md safeguard off, regardless.
  # jq: (template * existing) gives existing-wins; then force the guard key.
  merged_tmp="$(mktemp)"
  jq -s '
    .[0] as $template
    | .[1] as $existing
    | ($template * $existing)
    | .CLAUDE_MEM_FOLDER_CLAUDEMD_ENABLED = "false"
  ' "$SETTINGS_TEMPLATE" "$CLAUDE_MEM_SETTINGS" > "$merged_tmp"

  # Validate the merged JSON before replacing the live file.
  if ! jq empty "$merged_tmp" >/dev/null 2>&1; then
    print_error "Merged settings are not valid JSON — leaving existing file untouched"
    rm -f "$merged_tmp"
    exit 1
  fi

  mv "$merged_tmp" "$CLAUDE_MEM_SETTINGS"
  print_success "Merged settings into $CLAUDE_MEM_SETTINGS (safeguard forced off)"
fi

# Final validation of the deployed file.
if jq empty "$CLAUDE_MEM_SETTINGS" >/dev/null 2>&1; then
  print_success "Validated $CLAUDE_MEM_SETTINGS"
else
  print_error "Deployed settings are not valid JSON: $CLAUDE_MEM_SETTINGS"
  exit 1
fi

# =============================================================================
# Add the plugin marketplace (idempotent)
# =============================================================================
# `claude plugin marketplace list` prints the configured marketplaces and their
# GitHub source repos. We match on the repo slug so this is robust to whatever
# local name the marketplace is registered under.

if claude plugin marketplace list 2>/dev/null | grep -qi "$MARKETPLACE_REPO"; then
  print_success "Marketplace already added: $MARKETPLACE_REPO"
else
  print_info "Adding plugin marketplace: $MARKETPLACE_REPO"
  claude plugin marketplace add "$MARKETPLACE_REPO"
  print_success "Marketplace added: $MARKETPLACE_REPO"
fi

# =============================================================================
# Install the plugin (idempotent)
# =============================================================================

if claude plugin list 2>/dev/null | grep -qi "$PLUGIN_NAME"; then
  print_success "Plugin already installed: $PLUGIN_NAME"
else
  print_info "Installing plugin: ${PLUGIN_NAME}@${MARKETPLACE_NAME} (user scope)"
  claude plugin install "${PLUGIN_NAME}@${MARKETPLACE_NAME}" -s user
  print_success "Plugin installed: ${PLUGIN_NAME}@${MARKETPLACE_NAME}"
fi

# =============================================================================
# Verify
# =============================================================================

print_info "Verifying claude-mem plugin..."

if claude plugin list 2>/dev/null | grep -qi "$PLUGIN_NAME"; then
  print_success "claude-mem is present in the plugin list"
else
  print_error "claude-mem not found in plugin list after install"
  print_info "Check status with: claude plugin list"
  exit 1
fi

echo ""
print_success "claude-mem setup complete!"
print_info "The bun memory worker auto-starts on your next Claude Code session"

#!/usr/bin/env bash

# =============================================================================
# Machine Configuration
# =============================================================================
# Copies <repo>/claude/.claude/machine.template.json to ~/.claude/machine.json
# when missing; never overwrites. Run by install.sh and migrate-lean-config.sh.
#
# Usage: ./scripts/setup-machine.sh
# =============================================================================

set -euo pipefail

# Get the directory where this script's parent (dotfiles) is located
DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Source utilities
source "$DOTFILES_DIR/scripts/utils.sh"

print_header "Machine Configuration"

# Template path
TEMPLATE="$DOTFILES_DIR/claude/.claude/machine.template.json"
TARGET="$HOME/.claude/machine.json"

# Check 1: jq must exist
if ! command_exists jq; then
    print_error "jq not found"
    exit 1
fi

# Check 2: template must exist
if [ ! -f "$TEMPLATE" ]; then
    print_error "machine.template.json not found"
    exit 1
fi

# Check 3: template must be valid JSON
if ! jq -e . <"$TEMPLATE" >/dev/null 2>&1; then
    print_error "not valid JSON"
    exit 1
fi

# Check 4: $HOME/.claude must be a directory
if [ ! -d "$HOME/.claude" ]; then
    print_error "$HOME/.claude not found"
    exit 1
fi

# Check if target already exists (file or symlink, including dangling)
if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
    print_info "leaving unchanged: $TARGET"
    exit 0
fi

# Copy template to target
cp "$TEMPLATE" "$TARGET"
print_success "Created $TARGET"
print_info "Edit it to change agent caps for this machine"
exit 0

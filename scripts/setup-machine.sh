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

TEMPLATE="$DOTFILES_DIR/claude/.claude/machine.template.json"
TARGET="$HOME/.claude/machine.json"

if ! command_exists jq; then
    print_error "jq not found on PATH - install jq, then re-run setup-machine.sh"
    exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
    print_error "machine.template.json not found: $TEMPLATE"
    exit 1
fi

if ! jq empty <"$TEMPLATE" >/dev/null 2>&1; then
    print_error "$TEMPLATE is not valid JSON"
    exit 1
fi

if [ ! -d "$HOME/.claude" ]; then
    print_error "$HOME/.claude not found - stow claude/.claude first (run install.sh)"
    exit 1
fi

# Leave unchanged if target exists as file or symlink (including dangling)
if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
    print_info "$TARGET exists - leaving unchanged"
    exit 0
fi

cp "$TEMPLATE" "$TARGET"
print_success "Created $TARGET"
print_info "Edit it to change agent caps for this machine"
exit 0

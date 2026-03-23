#!/usr/bin/env bash

# =============================================================================
# Clean Ephemeral Claude Data
# =============================================================================
# Removes machine-local session/task data from ~/.claude, keeping only
# configuration that should persist between machines.
#
# Usage: ./scripts/clean-ephemeral.sh [--dry-run]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

CLAUDE_DIR="$HOME/.claude"

# Dirs and files matching .gitignore — ephemeral, machine-local state
EPHEMERAL_DIRS=(
  projects
  file-history
  session-env
  shell-snapshots
  sessions
  tasks
  todos
  plans
  debug
  backups
  cache
  paste-cache
  image-cache
  ide
)

EPHEMERAL_FILES=(
  history.jsonl
  stats-cache.json
  .credentials.json
)

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

if [[ ! -d "$CLAUDE_DIR" ]] && [[ ! -L "$CLAUDE_DIR" ]]; then
  print_error "~/.claude not found"
  exit 1
fi

print_header "Clean Ephemeral Claude Data"

if $DRY_RUN; then
  print_warning "DRY RUN — nothing will be deleted"
  echo ""
fi

total_size=0

for dir in "${EPHEMERAL_DIRS[@]}"; do
  target="$CLAUDE_DIR/$dir"
  if [[ -d "$target" ]]; then
    size=$(du -sh "$target" 2>/dev/null | cut -f1)
    if $DRY_RUN; then
      print_info "Would remove: $dir/ ($size)"
    else
      rm -rf "$target"
      print_success "Removed: $dir/ ($size)"
    fi
  fi
done

for file in "${EPHEMERAL_FILES[@]}"; do
  target="$CLAUDE_DIR/$file"
  if [[ -f "$target" ]]; then
    size=$(du -sh "$target" 2>/dev/null | cut -f1)
    if $DRY_RUN; then
      print_info "Would remove: $file ($size)"
    else
      rm -f "$target"
      print_success "Removed: $file ($size)"
    fi
  fi
done

echo ""
if $DRY_RUN; then
  print_info "Run without --dry-run to delete"
else
  remaining=$(du -sh "$CLAUDE_DIR" 2>/dev/null | cut -f1)
  print_success "Done. ~/.claude is now $remaining (config only)"
fi

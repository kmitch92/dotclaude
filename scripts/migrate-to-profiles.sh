#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"

# Source utility functions
# shellcheck source=scripts/utils.sh
source "${SCRIPT_DIR}/scripts/utils.sh"

cd "$REPO_ROOT"

# Parse --force flag
FORCE_FLAG=""
if [[ "${1:-}" == "-f" || "${1:-}" == "--force" ]]; then
    FORCE_FLAG="--force"
fi

# Check if already migrated
if [[ -d "profiles/default/.claude" ]] && [[ -f "profiles/default/.claude/CLAUDE.md" ]]; then
    print_info "Already migrated. Running switch-profile to ensure symlinks..."
    # shellcheck disable=SC2086 - intentional word splitting for optional flag
    "${SCRIPT_DIR}/scripts/switch-profile.sh" ${FORCE_FLAG} default
    exit 0
fi

print_header "Migration: claude/ -> profiles/ + runtime/"

# Step 1: Create target directories
print_info "[1/10] Creating profiles/default/.claude/ directory..."
mkdir -p profiles/default/.claude

# Step 2: Move CONFIG items using git mv (preserves history)
print_info "[2/10] Moving config items with git mv..."

# Single files
git mv claude/.claude/CLAUDE.md profiles/default/.claude/
git mv claude/.claude/CHANGELOG_TEMPLATE.md profiles/default/.claude/
git mv claude/.claude/settings.json profiles/default/.claude/

# Directories
git mv claude/.claude/agents profiles/default/.claude/
git mv claude/.claude/commands profiles/default/.claude/
git mv claude/.claude/docs profiles/default/.claude/
git mv claude/.claude/plugins profiles/default/.claude/
git mv claude/.claude/scripts profiles/default/.claude/

# Step 3: Create profiles/external/ for future submodules
print_info "[3/10] Creating profiles/external/ directory..."
mkdir -p profiles/external
touch profiles/external/.gitkeep

# Step 4: Create profiles/active symlink
print_info "[4/10] Creating profiles/active symlink -> default/..."
ln -s default profiles/active

# Step 5: Create runtime/ directory
print_info "[5/10] Creating runtime/ directory..."
mkdir -p runtime

# Step 6: Move RUNTIME items (untracked, use regular mv)
print_info "[6/10] Moving runtime items..."

runtime_items=(
    "cache"
    "debug"
    "file-history"
    "history.jsonl"
    "ide"
    "paste-cache"
    "plans"
    "projects"
    "session-env"
    "shell-snapshots"
    "stats-cache.json"
    "todos"
)

for item in "${runtime_items[@]}"; do
    if [[ -e "claude/.claude/$item" ]]; then
        print_success "  Moving $item..."
        mv "claude/.claude/$item" "runtime/"
    else
        print_info "  Skipping $item (does not exist)"
    fi
done

# Step 7: Handle .mcp.json - move to repo root as regular file
print_info "[7/10] Moving .mcp.json to repo root..."
if [[ -f "claude/.mcp.json" ]]; then
    # First remove the symlink at root
    if [[ -L ".mcp.json" ]]; then
        rm ".mcp.json"
    fi
    mv "claude/.mcp.json" ".mcp.json"
    print_success "  Moved claude/.mcp.json -> .mcp.json"
else
    print_info "  No claude/.mcp.json found"
fi

# Step 8: Remove empty claude/ directory
print_info "[8/10] Removing empty claude/ directory..."
if [[ -d "claude/.claude" ]]; then
    rmdir claude/.claude 2>/dev/null || { print_warning "  claude/.claude not empty, listing contents:"; ls -la claude/.claude 2>/dev/null || true; }
fi
if [[ -d "claude" ]]; then
    rmdir claude 2>/dev/null || { print_warning "  claude/ not empty, listing contents:"; ls -la claude 2>/dev/null || true; }
fi

# Step 9: Verify migration
print_info "[9/10] Verifying migration..."
echo ""
print_info "=== profiles/ structure ==="
ls -la profiles/
echo ""
print_info "=== profiles/default/.claude/ structure ==="
ls -la profiles/default/.claude/
echo ""
print_info "=== runtime/ structure ==="
ls -la runtime/
echo ""
print_info "=== Symlink verification ==="
ls -la profiles/active
echo ""
print_info "=== .mcp.json at root ==="
ls -la .mcp.json 2>/dev/null || echo "Not found"
echo ""

# Step 10: Set up ~/.claude symlinks
print_header "Setting up ~/.claude symlinks"
# shellcheck disable=SC2086 - intentional word splitting for optional flag
"${SCRIPT_DIR}/scripts/switch-profile.sh" ${FORCE_FLAG} default

print_header "Migration Complete"
print_warning "Remember: Do NOT run git commit yet per instructions."

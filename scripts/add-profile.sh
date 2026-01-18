#!/usr/bin/env bash

# =============================================================================
# Add External Profile as Git Submodule
# =============================================================================
# Adds an external Claude profile repository as a git submodule
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly EXTERNAL_PROFILES_DIR="$REPO_ROOT/profiles/external"

# Source utility functions
# shellcheck source=utils.sh
source "$SCRIPT_DIR/utils.sh"

# =============================================================================
# Functions
# =============================================================================

usage() {
  cat <<EOF
Usage: $(basename "$0") <git-url> [profile-name]

Add an external Claude profile repository as a git submodule.

Arguments:
  git-url       Git repository URL (required)
  profile-name  Name for the profile (optional, defaults to repo name)

Examples:
  $(basename "$0") https://github.com/user/their-dotclaude.git
  $(basename "$0") https://github.com/user/their-dotclaude.git custom-name
EOF
}

extract_repo_name() {
  local url="$1"
  local name

  # Remove trailing .git if present
  name="${url%.git}"
  # Extract last path component
  name="${name##*/}"

  echo "$name"
}

validate_git_url() {
  local url="$1"

  if [[ -z "$url" ]]; then
    print_error "Git URL is required"
    usage
    return 1
  fi

  # Basic URL validation
  if [[ ! "$url" =~ ^(https?://|git@|ssh://) ]]; then
    print_error "Invalid git URL format: $url"
    return 1
  fi

  return 0
}

validate_profile_name() {
  local name="$1"

  if [[ -z "$name" ]]; then
    print_error "Profile name cannot be empty"
    return 1
  fi

  # Check for invalid characters
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    print_error "Profile name can only contain alphanumeric characters, hyphens, and underscores"
    return 1
  fi

  return 0
}

profile_exists() {
  local name="$1"
  local profile_path="$EXTERNAL_PROFILES_DIR/$name"

  [[ -d "$profile_path" ]]
}

validate_profile_structure() {
  local profile_path="$1"
  local claude_dir="$profile_path/.claude"
  local has_valid_content=false

  # Check for .claude directory
  if [[ ! -d "$claude_dir" ]]; then
    print_error "Profile missing required .claude/ directory"
    return 1
  fi

  # Check for at least one of: CLAUDE.md, agents/, docs/
  if [[ -f "$claude_dir/CLAUDE.md" ]]; then
    has_valid_content=true
  fi

  if [[ -d "$claude_dir/agents" ]]; then
    has_valid_content=true
  fi

  if [[ -d "$claude_dir/docs" ]]; then
    has_valid_content=true
  fi

  # Also check root level CLAUDE.md
  if [[ -f "$profile_path/CLAUDE.md" ]]; then
    has_valid_content=true
  fi

  if [[ "$has_valid_content" != true ]]; then
    print_error "Profile .claude/ directory must contain at least one of: CLAUDE.md, agents/, docs/"
    return 1
  fi

  return 0
}

cleanup_submodule() {
  local name="$1"
  local profile_path="$EXTERNAL_PROFILES_DIR/$name"

  print_info "Cleaning up failed submodule..."

  # Remove submodule entry from .gitmodules
  if [[ -f "$REPO_ROOT/.gitmodules" ]]; then
    git -C "$REPO_ROOT" config --file .gitmodules --remove-section "submodule.profiles/external/$name" 2>/dev/null || true
  fi

  # Remove submodule entry from .git/config
  git -C "$REPO_ROOT" config --remove-section "submodule.profiles/external/$name" 2>/dev/null || true

  # Remove from index
  git -C "$REPO_ROOT" rm --cached "profiles/external/$name" 2>/dev/null || true

  # Remove directory
  rm -rf "$profile_path"

  # Remove from .git/modules
  rm -rf "$REPO_ROOT/.git/modules/profiles/external/$name"
}

add_profile() {
  local git_url="$1"
  local name="$2"
  local profile_path="$EXTERNAL_PROFILES_DIR/$name"

  print_header "Adding External Profile"

  # Validate inputs
  validate_git_url "$git_url" || return 1
  validate_profile_name "$name" || return 1

  # Check if profile already exists
  if profile_exists "$name"; then
    print_error "Profile '$name' already exists at: $profile_path"
    print_info "To use a different name, run:"
    print_info "  $(basename "$0") $git_url <different-name>"
    return 1
  fi

  # Ensure profiles/external directory exists
  ensure_directory "$EXTERNAL_PROFILES_DIR"

  # Add submodule
  print_info "Adding profile '$name' from $git_url..."
  if ! git -C "$REPO_ROOT" submodule add "$git_url" "profiles/external/$name" 2>&1; then
    print_error "Failed to add git submodule"
    cleanup_submodule "$name"
    return 1
  fi

  # Initialize and update submodule
  git -C "$REPO_ROOT" submodule update --init --recursive "profiles/external/$name"

  # Validate profile structure
  print_info "Validating profile structure..."
  if ! validate_profile_structure "$profile_path"; then
    print_error "Profile validation failed"
    cleanup_submodule "$name"
    return 1
  fi

  print_success "Profile added successfully."
  echo ""
  print_info "To switch to this profile:"
  print_info "  ./scripts/switch-profile.sh external/$name"
}

# =============================================================================
# Main
# =============================================================================

main() {
  local git_url="${1:-}"
  local name="${2:-}"

  # Show usage if no arguments
  if [[ -z "$git_url" ]]; then
    usage
    exit 1
  fi

  # Extract repo name if not provided
  if [[ -z "$name" ]]; then
    name=$(extract_repo_name "$git_url")
  fi

  # Verify we're in a git repository
  if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print_error "Not inside a git repository"
    exit 1
  fi

  # Require git
  require_command git || exit 1

  add_profile "$git_url" "$name"
}

main "$@"

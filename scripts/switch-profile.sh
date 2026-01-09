#!/usr/bin/env bash

# =============================================================================
# Profile Switcher for dotclaude Multi-Profile System
# =============================================================================
# Switches the active Claude configuration profile by updating symlinks.
#
# Usage:
#   ./scripts/switch-profile.sh <profile-name>
#   ./scripts/switch-profile.sh default
#   ./scripts/switch-profile.sh external/someone-config
# =============================================================================

set -euo pipefail

# Determine script and repo locations
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROFILES_DIR="${REPO_ROOT}/profiles"
readonly RUNTIME_DIR="${REPO_ROOT}/runtime"
readonly CLAUDE_HOME="${HOME}/.claude"

# Source utility functions
# shellcheck source=utils.sh
source "${SCRIPT_DIR}/utils.sh"

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

# Config items: symlinked from profile .claude/ directory
readonly CONFIG_ITEMS=(
  "CLAUDE.md"
  "settings.json"
  "agents"
  "commands"
  "docs"
  "plugins"
  "scripts"
  "skills"
)

# Runtime items: symlinked from runtime/ directory (shared across profiles)
readonly RUNTIME_ITEMS=(
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

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

usage() {
  cat <<EOF
Usage: $(basename "$0") <profile-name>

Switches the active Claude configuration profile.

Arguments:
  profile-name    Name of profile to activate (e.g., 'default', 'external/someone-config')

Examples:
  $(basename "$0") default
  $(basename "$0") external/someone-config

Profiles are located in:
  ${PROFILES_DIR}/           (local profiles)
  ${PROFILES_DIR}/external/  (submodule profiles)
EOF
  exit 1
}

validate_profile() {
  local profile_name="$1"
  local profile_path="${PROFILES_DIR}/${profile_name}"

  if [[ ! -d "${profile_path}" ]]; then
    print_error "Profile not found: ${profile_name}"
    print_info "Expected location: ${profile_path}"

    # List available profiles
    if [[ -d "${PROFILES_DIR}" ]]; then
      echo ""
      print_info "Available profiles:"
      find "${PROFILES_DIR}" -mindepth 1 -maxdepth 2 -type d -name ".claude" | while read -r claude_dir; do
        local pdir
        pdir="$(dirname "${claude_dir}")"
        local pname="${pdir#${PROFILES_DIR}/}"
        echo "  - ${pname}"
      done
    fi
    return 1
  fi

  if [[ ! -d "${profile_path}/.claude" ]]; then
    print_error "Profile is missing .claude/ directory: ${profile_name}"
    print_info "A valid profile must contain a .claude/ directory"
    return 1
  fi

  return 0
}

remove_existing_symlinks() {
  print_info "Removing existing symlinks in ${CLAUDE_HOME}..."

  local item
  for item in "${CONFIG_ITEMS[@]}" "${RUNTIME_ITEMS[@]}"; do
    local target="${CLAUDE_HOME}/${item}"
    if [[ -L "${target}" ]]; then
      rm "${target}"
    elif [[ -e "${target}" ]]; then
      print_warning "Skipping non-symlink: ${target}"
    fi
  done
}

update_active_symlink() {
  local profile_name="$1"
  local active_link="${PROFILES_DIR}/active"
  local profile_path="${PROFILES_DIR}/${profile_name}"

  print_info "Updating active profile symlink..."

  # Remove existing active symlink
  if [[ -L "${active_link}" ]]; then
    rm "${active_link}"
  elif [[ -e "${active_link}" ]]; then
    print_error "'active' exists but is not a symlink: ${active_link}"
    print_info "Please remove it manually and try again"
    return 1
  fi

  # Create new symlink (relative path for portability)
  ln -s "${profile_name}" "${active_link}"
  print_success "Active profile: ${profile_name}"
}

create_config_symlinks() {
  local active_claude="${PROFILES_DIR}/active/.claude"

  print_info "Creating config symlinks..."

  local item
  for item in "${CONFIG_ITEMS[@]}"; do
    local source="${active_claude}/${item}"
    local target="${CLAUDE_HOME}/${item}"

    if [[ -e "${source}" ]]; then
      ln -s "${source}" "${target}"
      print_success "Linked: ${item}"
    else
      print_info "Skipped (not in profile): ${item}"
    fi
  done
}

create_runtime_symlinks() {
  print_info "Creating runtime symlinks..."

  # Ensure runtime directory exists
  ensure_directory "${RUNTIME_DIR}"

  local item
  for item in "${RUNTIME_ITEMS[@]}"; do
    local source="${RUNTIME_DIR}/${item}"
    local target="${CLAUDE_HOME}/${item}"

    # Create runtime item if it doesn't exist
    if [[ ! -e "${source}" ]]; then
      if [[ "${item}" == *.* ]]; then
        # File (has extension)
        touch "${source}"
      else
        # Directory
        mkdir -p "${source}"
      fi
      print_info "Created runtime: ${item}"
    fi

    ln -s "${source}" "${target}"
    print_success "Linked: ${item} (runtime)"
  done
}

ensure_claude_home() {
  if [[ ! -d "${CLAUDE_HOME}" ]]; then
    print_info "Creating ${CLAUDE_HOME}..."
    mkdir -p "${CLAUDE_HOME}"
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  if [[ $# -lt 1 ]]; then
    usage
  fi

  local profile_name="$1"

  print_header "Switching Claude Profile"

  # Validate profile exists
  if ! validate_profile "${profile_name}"; then
    exit 1
  fi

  # Ensure ~/.claude exists
  ensure_claude_home

  # Remove existing symlinks
  remove_existing_symlinks

  # Update active profile symlink
  if ! update_active_symlink "${profile_name}"; then
    exit 1
  fi

  # Create new symlinks
  create_config_symlinks
  create_runtime_symlinks

  echo ""
  print_header "Profile Switched Successfully"
  print_success "Active profile: ${profile_name}"
  echo ""
  print_warning "Please restart Claude Code for changes to take effect"
  echo ""
}

main "$@"

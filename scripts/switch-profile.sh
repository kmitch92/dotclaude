#!/usr/bin/env bash

# =============================================================================
# Profile Switcher for dotclaude Multi-Profile System
# =============================================================================
# Switches the active Claude configuration profile by updating symlinks.
#
# Usage:
#   ./scripts/switch-profile.sh [-f|--force] <profile-name>
#   ./scripts/switch-profile.sh default
#   ./scripts/switch-profile.sh --force default
#   ./scripts/switch-profile.sh external/someone-config
# =============================================================================

set -euo pipefail

# Determine script and repo locations
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROFILES_DIR="${REPO_ROOT}/profiles"
readonly RUNTIME_DIR="${REPO_ROOT}/runtime"
readonly CLAUDE_HOME="${CLAUDE_HOME:-${HOME}/.claude}"

# Force mode flag
FORCE_MODE=false

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

# Get the path to .claude/ directory for a profile, accounting for subpath config
# Args: profile_name
# Output: Prints the path to .claude/ directory
get_profile_claude_path() {
  local profile_name="$1"
  local profile_path="${PROFILES_DIR}/${profile_name}"
  local config_file="${profile_path}/.profile-config"

  if [[ -f "${config_file}" ]]; then
    local subpath=""
    # Source config file to get SUBPATH variable
    # shellcheck source=/dev/null
    subpath=$(grep -E '^SUBPATH=' "${config_file}" 2>/dev/null | cut -d'=' -f2 || true)
    if [[ -n "${subpath}" ]]; then
      echo "${profile_path}/${subpath}/.claude"
      return 0
    fi
  fi

  echo "${profile_path}/.claude"
}

# Get the subpath for a profile (empty if none configured)
# Args: profile_name
# Output: Prints the subpath or empty string
get_profile_subpath() {
  local profile_name="$1"
  local profile_path="${PROFILES_DIR}/${profile_name}"
  local config_file="${profile_path}/.profile-config"

  if [[ -f "${config_file}" ]]; then
    local subpath=""
    subpath=$(grep -E '^SUBPATH=' "${config_file}" 2>/dev/null | cut -d'=' -f2 || true)
    if [[ -n "${subpath}" ]]; then
      echo "${subpath}"
      return 0
    fi
  fi

  echo ""
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [-f|--force] <profile-name>

Switches the active Claude configuration profile.

Options:
  -f, --force     Force switch even if Claude is running or non-symlinks exist.
                  Backs up existing config files before replacing.

Arguments:
  profile-name    Name of profile to activate (e.g., 'default', 'external/someone-config')

Examples:
  $(basename "$0") default
  $(basename "$0") --force default
  $(basename "$0") -f external/someone-config

Profiles are located in:
  ${PROFILES_DIR}/           (local profiles)
  ${PROFILES_DIR}/external/  (submodule profiles)
EOF
  exit 1
}

check_claude_running() {
  local claude_pids
  claude_pids=$(pgrep -f "claude" 2>/dev/null || true)

  if [[ -n "${claude_pids}" ]]; then
    if [[ "${FORCE_MODE}" == "true" ]]; then
      print_warning "Claude processes detected (PIDs: ${claude_pids})"
      print_warning "Continuing in force mode - changes may not take effect until Claude restarts"
    else
      print_error "Claude is currently running (PIDs: ${claude_pids})"
      print_info "Please close Claude before switching profiles, or use --force to continue anyway"
      exit 1
    fi
  fi
}

backup_items_to_dir() {
  local backup_dir="$1"
  shift
  local items=("$@")

  local item
  for item in "${items[@]}"; do
    local source="${CLAUDE_HOME}/${item}"
    if [[ -e "${source}" ]] && [[ ! -L "${source}" ]]; then
      mv "${source}" "${backup_dir}/"
      print_success "Backed up: ${item}"
    fi
  done
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
      find "${PROFILES_DIR}" -mindepth 1 -maxdepth 3 -type d -name ".claude" | while read -r claude_dir; do
        local pdir
        pdir="$(dirname "${claude_dir}")"
        local pname="${pdir#${PROFILES_DIR}/}"
        echo "  - ${pname}"
      done
    fi
    return 1
  fi

  # Get the actual .claude/ path (accounting for subpath config)
  local claude_path
  claude_path="$(get_profile_claude_path "${profile_name}")"

  if [[ ! -d "${claude_path}" ]]; then
    print_error "Profile is missing .claude/ directory: ${profile_name}"
    local subpath
    subpath="$(get_profile_subpath "${profile_name}")"
    if [[ -n "${subpath}" ]]; then
      print_info "Expected location (with subpath '${subpath}'): ${claude_path}"
    else
      print_info "Expected location: ${claude_path}"
    fi
    print_info "A valid profile must contain a .claude/ directory"
    return 1
  fi

  return 0
}

prepare_claude_home() {
  print_info "Preparing ${CLAUDE_HOME}..."

  local config_non_symlinks=()
  local runtime_non_symlinks=()

  # Check for non-symlinks in config items
  local item
  for item in "${CONFIG_ITEMS[@]}"; do
    local target="${CLAUDE_HOME}/${item}"
    if [[ -e "${target}" ]] && [[ ! -L "${target}" ]]; then
      config_non_symlinks+=("${item}")
    fi
  done

  # Check for non-symlinks in runtime items
  for item in "${RUNTIME_ITEMS[@]}"; do
    local target="${CLAUDE_HOME}/${item}"
    if [[ -e "${target}" ]] && [[ ! -L "${target}" ]]; then
      runtime_non_symlinks+=("${item}")
    fi
  done

  # Handle config non-symlinks (require force mode)
  if [[ ${#config_non_symlinks[@]} -gt 0 ]]; then
    if [[ "${FORCE_MODE}" != "true" ]]; then
      print_error "Non-symlink config files found in ${CLAUDE_HOME}"
      print_info "This appears to be an initial migration from a standard Claude setup"
      print_info "Use --force to back up existing files and proceed"
      exit 1
    fi
  fi

  # If force mode and we have non-symlinks, back them up
  if [[ "${FORCE_MODE}" == "true" ]]; then
    local needs_backup=false
    if [[ ${#config_non_symlinks[@]} -gt 0 ]] || [[ ${#runtime_non_symlinks[@]} -gt 0 ]]; then
      needs_backup=true
    fi

    if [[ "${needs_backup}" == "true" ]]; then
      local backup_dir="${HOME}/.claude-backup-$(date +%Y%m%d-%H%M%S)"
      print_info "Backing up existing items to ${backup_dir}..."
      mkdir -p "${backup_dir}"

      if [[ ${#config_non_symlinks[@]} -gt 0 ]]; then
        backup_items_to_dir "${backup_dir}" "${config_non_symlinks[@]}"
      fi

      if [[ ${#runtime_non_symlinks[@]} -gt 0 ]]; then
        backup_items_to_dir "${backup_dir}" "${runtime_non_symlinks[@]}"
      fi

      print_success "Backup complete: ${backup_dir}"
    fi
  fi

  # Remove all symlinks
  for item in "${CONFIG_ITEMS[@]}" "${RUNTIME_ITEMS[@]}"; do
    local target="${CLAUDE_HOME}/${item}"
    if [[ -L "${target}" ]]; then
      rm "${target}"
    elif [[ -e "${target}" ]]; then
      # Non-symlink still exists after backup - should not happen for config items
      local is_runtime=false
      for runtime_item in "${RUNTIME_ITEMS[@]}"; do
        if [[ "${item}" == "${runtime_item}" ]]; then
          is_runtime=true
          break
        fi
      done
      if [[ "${is_runtime}" == "true" ]]; then
        # Runtime item not in force mode - warn but continue
        print_warning "Skipping non-symlink runtime item: ${target}"
      else
        print_error "Unexpected non-symlink config item: ${target}"
        exit 1
      fi
    fi
  done
}

update_active_symlink() {
  local profile_name="$1"
  local active_link="${PROFILES_DIR}/active"

  print_info "Updating active profile symlink..."

  # Remove existing active symlink
  if [[ -L "${active_link}" ]]; then
    rm "${active_link}"
  elif [[ -e "${active_link}" ]]; then
    print_error "'active' exists but is not a symlink: ${active_link}"
    print_info "Please remove it manually and try again"
    return 1
  fi

  # Determine symlink target (profile_name or profile_name/subpath)
  local subpath
  subpath="$(get_profile_subpath "${profile_name}")"
  local symlink_target="${profile_name}"

  if [[ -n "${subpath}" ]]; then
    symlink_target="${profile_name}/${subpath}"
    print_info "Profile uses subpath: ${subpath}"
  fi

  # Create new symlink (relative path for portability)
  ln -s "${symlink_target}" "${active_link}"
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
  # Parse flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--force)
        FORCE_MODE=true
        shift
        ;;
      -*)
        print_error "Unknown option: $1"
        usage
        ;;
      *)
        break
        ;;
    esac
  done

  if [[ $# -lt 1 ]]; then
    usage
  fi

  local profile_name="$1"

  print_header "Switching Claude Profile"

  # Check if Claude is running (early check before any modifications)
  check_claude_running

  # Validate profile exists
  if ! validate_profile "${profile_name}"; then
    exit 1
  fi

  # Ensure ~/.claude exists
  ensure_claude_home

  # Prepare claude home (remove symlinks, handle non-symlinks)
  prepare_claude_home

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

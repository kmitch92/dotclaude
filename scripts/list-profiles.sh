#!/usr/bin/env bash

# =============================================================================
# Profile Listing Script
# =============================================================================
# Lists all available Claude configuration profiles with status and statistics
#
# Usage: ./scripts/list-profiles.sh
# =============================================================================

set -euo pipefail

# Get the directory where this script's parent (dotclaude) is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly PROFILES_DIR="$REPO_ROOT/profiles"

# Source utilities
# shellcheck source=utils.sh
source "$SCRIPT_DIR/utils.sh"

# =============================================================================
# Helper Functions
# =============================================================================

# Get the path to .claude/ directory for a profile, accounting for subpath config
# Args: profile_path (full path to profile directory)
# Output: Prints the path to .claude/ directory
get_profile_claude_path() {
    local profile_path="$1"
    local config_file="${profile_path}/.profile-config"

    if [[ -f "${config_file}" ]]; then
        local subpath=""
        subpath=$(grep -E '^SUBPATH=' "${config_file}" 2>/dev/null | cut -d'=' -f2 || true)
        if [[ -n "${subpath}" ]]; then
            echo "${profile_path}/${subpath}/.claude"
            return 0
        fi
    fi

    echo "${profile_path}/.claude"
}

# Get the subpath for a profile (empty if none configured)
# Args: profile_path (full path to profile directory)
# Output: Prints the subpath or empty string
get_profile_subpath() {
    local profile_path="$1"
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

# Get the currently active profile name (from symlink target)
get_active_profile() {
    local active_link="$PROFILES_DIR/active"

    if [[ -L "$active_link" ]]; then
        local target
        target=$(readlink "$active_link")
        # Remove trailing slash if present
        target="${target%/}"
        # Return just the profile name (basename)
        basename "$target"
    else
        echo ""
    fi
}

# Count files recursively in a directory
count_files() {
    local dir="$1"

    if [[ -d "$dir" ]]; then
        # Cross-platform: use find with -type f
        find "$dir" -type f 2>/dev/null | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

# Check if directory exists and has content
has_directory() {
    local dir="$1"
    [[ -d "$dir" ]] && [[ -n "$(ls -A "$dir" 2>/dev/null)" ]]
}

# Get profile statistics
# Returns: "agents docs commands" (space-separated counts)
get_profile_stats() {
    local profile_path="$1"
    local claude_dir
    claude_dir=$(get_profile_claude_path "$profile_path")

    local agents=0
    local docs=0
    local commands=0

    # Count agents
    if [[ -d "$claude_dir/agents" ]]; then
        agents=$(count_files "$claude_dir/agents")
    fi

    # Count docs
    if [[ -d "$claude_dir/docs" ]]; then
        docs=$(count_files "$claude_dir/docs")
    fi

    # Count commands
    if [[ -d "$claude_dir/commands" ]]; then
        commands=$(count_files "$claude_dir/commands")
    fi

    echo "$agents $docs $commands"
}

# Print a single profile entry
print_profile_entry() {
    local name="$1"
    local path="$2"
    local is_active="$3"

    local marker=""
    if [[ "$is_active" == "true" ]]; then
        marker=" (active)"
    fi

    # Check for subpath
    local subpath
    subpath=$(get_profile_subpath "$path")
    local subpath_indicator=""
    if [[ -n "$subpath" ]]; then
        subpath_indicator=" (subpath: ${subpath})"
    fi

    # Get stats
    local stats
    stats=$(get_profile_stats "$path")
    read -r agents docs commands <<< "$stats"

    # Print profile name with active marker and subpath indicator
    if [[ "$is_active" == "true" ]]; then
        echo "  * ${name}${marker}${subpath_indicator}"
    else
        echo "    ${name}${subpath_indicator}"
    fi

    # Print stats line
    echo "      ${agents} agents, ${docs} docs, ${commands} commands"
    echo ""
}

# =============================================================================
# Main Logic
# =============================================================================

main() {
    print_header "Available Profiles"

    # Check if profiles directory exists
    if [[ ! -d "$PROFILES_DIR" ]]; then
        print_warning "No profiles directory found at: $PROFILES_DIR"
        print_info "Create profiles by adding directories to: $PROFILES_DIR"
        echo ""
        print_info "Expected structure:"
        echo "  profiles/"
        echo "    default/         # Local profile"
        echo "      .claude/"
        echo "        agents/"
        echo "        docs/"
        echo "        commands/"
        echo "    external/        # External profiles (submodules)"
        echo "      awesome-config/"
        echo "    active -> default/  # Symlink to active profile"
        exit 0
    fi

    # Get active profile
    local active_profile
    active_profile=$(get_active_profile)

    # Collect local profiles (excluding 'external' and 'active')
    local local_profiles=()
    local external_profiles=()

    for entry in "$PROFILES_DIR"/*; do
        [[ -e "$entry" ]] || continue

        local name
        name=$(basename "$entry")

        # Skip the active symlink
        [[ "$name" == "active" ]] && continue

        # Skip if not a directory
        [[ -d "$entry" ]] || continue

        # Categorize: external subdir vs local profile
        if [[ "$name" == "external" ]]; then
            # Collect external profiles
            for ext_entry in "$entry"/*; do
                [[ -e "$ext_entry" ]] || continue
                [[ -d "$ext_entry" ]] || continue
                external_profiles+=("$ext_entry")
            done
        else
            local_profiles+=("$entry")
        fi
    done

    # Check if any profiles exist
    if [[ ${#local_profiles[@]} -eq 0 ]] && [[ ${#external_profiles[@]} -eq 0 ]]; then
        print_warning "No profiles found in: $PROFILES_DIR"
        print_info "Add profile directories to get started."
        exit 0
    fi

    # Sort and print local profiles
    if [[ ${#local_profiles[@]} -gt 0 ]]; then
        echo "Local profiles:"

        # Sort profiles alphabetically
        IFS=$'\n' sorted_local=($(printf '%s\n' "${local_profiles[@]}" | sort))
        unset IFS

        for profile_path in "${sorted_local[@]}"; do
            local name
            name=$(basename "$profile_path")

            local is_active="false"
            [[ "$name" == "$active_profile" ]] && is_active="true"

            print_profile_entry "$name" "$profile_path" "$is_active"
        done
    fi

    # Sort and print external profiles
    if [[ ${#external_profiles[@]} -gt 0 ]]; then
        echo "External profiles (submodules):"

        # Sort profiles alphabetically
        IFS=$'\n' sorted_external=($(printf '%s\n' "${external_profiles[@]}" | sort))
        unset IFS

        for profile_path in "${sorted_external[@]}"; do
            local name
            name="external/$(basename "$profile_path")"

            local is_active="false"
            [[ "$name" == "$active_profile" ]] && is_active="true"

            print_profile_entry "$name" "$profile_path" "$is_active"
        done
    fi

    # Show active profile info
    if [[ -n "$active_profile" ]]; then
        print_info "Active profile: $active_profile"
    else
        print_warning "No active profile set. Use: ln -s <profile>/ profiles/active"
    fi
}

main "$@"

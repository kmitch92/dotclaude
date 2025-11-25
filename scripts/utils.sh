#!/usr/bin/env bash

# =============================================================================
# Utility Functions for dotclaude Scripts
# =============================================================================
# Common functions used across installation and setup scripts
# =============================================================================

# Color codes (using $'...' syntax to create actual escape sequences)
readonly GREEN=$'\033[0;32m'
readonly YELLOW=$'\033[1;33m'
readonly RED=$'\033[0;31m'
readonly BLUE=$'\033[0;34m'
readonly NC=$'\033[0m' # No Color

# =============================================================================
# Output Functions
# =============================================================================

print_header() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

print_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1" >&2
}

# =============================================================================
# OS Detection
# =============================================================================

is_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

is_linux() {
  [[ "$(uname -s)" == "Linux" ]]
}

detect_os() {
  if is_macos; then
    echo "macos"
  elif is_linux; then
    echo "linux"
  else
    echo "unknown"
  fi
}

# =============================================================================
# Command Checks
# =============================================================================

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_command() {
  local cmd="$1"
  local package="${2:-$cmd}"

  if ! command_exists "$cmd"; then
    print_error "$cmd is required but not installed"
    print_info "Install: $package"
    return 1
  fi
  return 0
}

# =============================================================================
# User Interaction
# =============================================================================

confirm() {
  local prompt="$1"
  local response

  read -rp "$prompt [y/N]: " response
  response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
  [[ "$response" == "y" ]]
}

# =============================================================================
# File Operations
# =============================================================================

backup_file() {
  local file="$1"
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local backup="${file}.backup.${timestamp}"

  if [[ -e "$file" ]]; then
    cp -r "$file" "$backup"
    print_success "Backed up: $file → $backup"
    echo "$backup"
  fi
}

ensure_directory() {
  local dir="$1"

  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    print_info "Created directory: $dir"
  fi
}

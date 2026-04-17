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
# Claude Install Method Detection
# =============================================================================
# Classify how the given `claude` binary was installed.
# Echoes exactly one of: native | brew | npm | unknown
# Returns 0 on successful classification, 1 on usage/arg errors.
# Bash 3.2 compatible (macOS default).

_resolve_symlink_chain() {
  # Resolve a symlink chain without `readlink -f` (bash 3.2 / macOS safe).
  local path="$1"
  local target
  local max_hops=40
  local hops=0

  while [ -L "$path" ]; do
    hops=$((hops + 1))
    if [ "$hops" -gt "$max_hops" ]; then
      break
    fi
    target="$(readlink "$path")"
    case "$target" in
      /*) path="$target" ;;
      *)  path="$(dirname "$path")/$target" ;;
    esac
  done
  echo "$path"
}

detect_claude_install_method() {
  local binary="${1:-}"

  if [ -z "$binary" ]; then
    return 1
  fi
  if [ ! -e "$binary" ]; then
    return 1
  fi
  if [ ! -x "$binary" ]; then
    return 1
  fi

  local resolved
  resolved="$(_resolve_symlink_chain "$binary")"

  # 1. native — under */share/claude/versions/* OR $HOME/.local/share/claude/*
  case "$resolved" in
    */share/claude/versions/*)
      echo "native"
      return 0
      ;;
  esac
  if [ -n "${HOME:-}" ]; then
    case "$resolved" in
      "${HOME}/.local/share/claude/"*)
        echo "native"
        return 0
        ;;
    esac
  fi

  # 2. npm — path contains node_modules/@anthropic-ai/claude-code/
  #          OR path is under `npm root -g` global prefix.
  case "$resolved" in
    *"/node_modules/@anthropic-ai/claude-code/"*)
      echo "npm"
      return 0
      ;;
  esac
  if command -v npm >/dev/null 2>&1; then
    local npm_root npm_prefix
    npm_root="$(npm root -g 2>/dev/null)"
    if [ -n "$npm_root" ]; then
      # Strip trailing /lib/node_modules (or /node_modules) to get npm global prefix.
      npm_prefix="${npm_root%/lib/node_modules}"
      if [ "$npm_prefix" = "$npm_root" ]; then
        npm_prefix="${npm_root%/node_modules}"
      fi
      case "$resolved" in
        "${npm_root}/"*)
          echo "npm"
          return 0
          ;;
        "${npm_prefix}/"*)
          echo "npm"
          return 0
          ;;
      esac
    fi
  fi

  # 3. brew — resolved path under brew prefix (honours BREW_PREFIX_OVERRIDE).
  local brew_prefix=""
  if [ -n "${BREW_PREFIX_OVERRIDE:-}" ]; then
    brew_prefix="$BREW_PREFIX_OVERRIDE"
  elif command -v brew >/dev/null 2>&1; then
    brew_prefix="$(brew --prefix 2>/dev/null)"
  fi
  if [ -n "$brew_prefix" ]; then
    case "$resolved" in
      "${brew_prefix}/"*)
        echo "brew"
        return 0
        ;;
    esac
  fi

  # 4. fall-through
  echo "unknown"
  return 0
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

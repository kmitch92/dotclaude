#!/usr/bin/env bash

# =============================================================================
# dotclaude Master Installation Script
# =============================================================================
# Comprehensive installation script for Claude Code configuration with MCP servers
#
# Features:
# - OS detection (macOS/Linux)
# - Dependency installation (Stow, Node.js, gettext)
# - Configuration backup
# - Symlink management with GNU Stow
# - MCP server configuration deployment
# - Validation and verification
#
# Usage: ./install.sh [OPTIONS]
#
# Options:
#   --skip-deps     Skip dependency installation
#   --no-backup     Skip backup creation
#   --help          Show this help message
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# Get the directory where this script is located
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities
source "$SCRIPT_DIR/scripts/utils.sh"

# =============================================================================
# Configuration
# =============================================================================

readonly CLAUDE_CONFIG_DIR="$HOME/.claude"
readonly MCP_CONFIG_FILE="$HOME/.mcp.json"
readonly PROFILES_DIR="$SCRIPT_DIR/profiles"

# Option flags
SKIP_DEPS=false
NO_BACKUP=false

# =============================================================================
# Usage Information
# =============================================================================

show_usage() {
  cat << EOF
dotclaude Installation Script

Usage: $0 [OPTIONS]

Options:
  --skip-deps     Skip dependency installation (use if deps already installed)
  --no-backup     Skip backup creation (use with caution)
  --help          Show this help message

Examples:
  $0                    # Full installation with all steps
  $0 --skip-deps        # Skip dependency checks
  $0 --no-backup        # Skip backup (not recommended)

EOF
}

# =============================================================================
# Parse Arguments
# =============================================================================

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-deps)
        SKIP_DEPS=true
        shift
        ;;
      --no-backup)
        NO_BACKUP=true
        shift
        ;;
      --help|-h)
        show_usage
        exit 0
        ;;
      *)
        print_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
  done
}

# =============================================================================
# Dependency Installation
# =============================================================================

install_stow() {
  print_info "Checking for GNU Stow..."

  if command_exists stow; then
    print_success "GNU Stow already installed"
    return 0
  fi

  print_warning "GNU Stow not found"

  if ! confirm "Install GNU Stow?"; then
    print_error "GNU Stow is required for configuration management"
    exit 1
  fi

  if is_macos; then
    print_info "Installing GNU Stow via Homebrew..."
    if ! command_exists brew; then
      print_error "Homebrew not found. Please install Homebrew first:"
      print_info "Visit: https://brew.sh"
      exit 1
    fi
    brew install stow
    print_success "GNU Stow installed"
  elif is_linux; then
    print_info "Installing GNU Stow via package manager..."
    if command_exists apt-get; then
      sudo apt-get update
      sudo apt-get install -y stow
    elif command_exists dnf; then
      sudo dnf install -y stow
    elif command_exists pacman; then
      sudo pacman -S --noconfirm stow
    else
      print_error "Could not detect package manager. Please install GNU Stow manually."
      exit 1
    fi
    print_success "GNU Stow installed"
  else
    print_error "Unsupported OS: $(uname -s)"
    exit 1
  fi
}

install_nodejs() {
  print_info "Checking for Node.js/npm..."

  if command_exists node && command_exists npm; then
    local node_version
    node_version=$(node --version)
    print_success "Node.js already installed: $node_version"
    return 0
  fi

  print_warning "Node.js/npm not found"
  print_info "Node.js is needed for:"
  print_info "  - Claude Code installation"
  print_info "  - MCP servers (context7, sequential-thinking, playwright)"

  if ! confirm "Install Node.js?"; then
    print_warning "Skipping Node.js installation"
    print_info "Note: Some features may not work without Node.js"
    return 0
  fi

  if is_macos; then
    print_info "Installing Node.js via Homebrew..."
    if ! command_exists brew; then
      print_error "Homebrew not found. Please install Homebrew first:"
      print_info "Visit: https://brew.sh"
      exit 1
    fi
    brew install node
    print_success "Node.js installed"
  elif is_linux; then
    print_info "Installing Node.js via package manager..."
    if command_exists apt-get; then
      curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
      sudo apt-get install -y nodejs
    elif command_exists dnf; then
      sudo dnf install -y nodejs npm
    elif command_exists pacman; then
      sudo pacman -S --noconfirm nodejs npm
    else
      print_error "Could not detect package manager. Please install Node.js manually."
      exit 1
    fi
    print_success "Node.js installed"
  fi
}

install_gettext() {
  print_info "Checking for gettext (envsubst)..."

  if command_exists envsubst; then
    print_success "gettext already installed"
    return 0
  fi

  print_warning "gettext not found (needed for MCP configuration)"

  if ! confirm "Install gettext?"; then
    print_error "gettext is required for MCP setup"
    exit 1
  fi

  if is_macos; then
    print_info "Installing gettext via Homebrew..."
    brew install gettext
    # Add gettext to PATH for current session
    export PATH="/usr/local/opt/gettext/bin:$PATH"
    print_success "gettext installed"
  elif is_linux; then
    print_info "Installing gettext via package manager..."
    if command_exists apt-get; then
      sudo apt-get install -y gettext-base
    elif command_exists dnf; then
      sudo dnf install -y gettext
    elif command_exists pacman; then
      sudo pacman -S --noconfirm gettext
    else
      print_error "Could not detect package manager. Please install gettext manually."
      exit 1
    fi
    print_success "gettext installed"
  fi
}

check_dependencies() {
  print_header "Checking Dependencies"

  local deps_ok=true

  # Check GNU Stow
  if ! command_exists stow; then
    print_error "GNU Stow not installed"
    deps_ok=false
  else
    print_success "GNU Stow installed"
  fi

  # Check gettext (envsubst)
  if ! command_exists envsubst; then
    print_error "gettext (envsubst) not installed"
    deps_ok=false
  else
    print_success "gettext installed"
  fi

  # Check Node.js (optional but recommended)
  if ! command_exists node; then
    print_warning "Node.js not installed (needed for Claude Code and MCP servers)"
  else
    local node_version
    node_version=$(node --version)
    print_success "Node.js installed: $node_version"
  fi

  if [[ "$deps_ok" == "false" ]]; then
    print_error "Missing required dependencies"
    return 1
  fi

  return 0
}

install_dependencies() {
  print_header "Installing Dependencies"

  install_stow
  install_gettext
  install_nodejs

  print_success "All dependencies installed"
}

# =============================================================================
# Backup Configuration
# =============================================================================

backup_existing_config() {
  print_header "Backing Up Existing Configuration"

  local backed_up=false

  # Backup ~/.claude
  if [[ -e "$CLAUDE_CONFIG_DIR" ]]; then
    local backup_path
    backup_path=$(backup_file "$CLAUDE_CONFIG_DIR")
    print_success "Backed up ~/.claude"
    # Remove original after backup (unless it's already a symlink, handled later)
    if [[ ! -L "$CLAUDE_CONFIG_DIR" ]]; then
      rm -rf "$CLAUDE_CONFIG_DIR"
      print_info "Removed original ~/.claude directory"
    fi
    backed_up=true
  else
    print_info "No existing ~/.claude directory found"
  fi

  # Backup ~/.mcp.json
  if [[ -e "$MCP_CONFIG_FILE" ]]; then
    local backup_path
    backup_path=$(backup_file "$MCP_CONFIG_FILE")
    print_success "Backed up ~/.mcp.json"
    # Remove original after backup
    if [[ ! -L "$MCP_CONFIG_FILE" ]]; then
      rm -f "$MCP_CONFIG_FILE"
      print_info "Removed original ~/.mcp.json file"
    fi
    backed_up=true
  else
    print_info "No existing ~/.mcp.json file found"
  fi

  if [[ "$backed_up" == "false" ]]; then
    print_info "No existing configuration to backup"
  fi
}

# =============================================================================
# Configuration Installation
# =============================================================================

install_claude_config() {
  print_header "Installing Claude Configuration"

  cd "$SCRIPT_DIR"

  # Remove existing ~/.claude if it's a symlink (from previous stow)
  if [[ -L "$CLAUDE_CONFIG_DIR" ]]; then
    print_info "Found existing symlink at ~/.claude, removing..."
    rm "$CLAUDE_CONFIG_DIR"
  fi

  # Remove existing ~/.claude directory if it exists
  if [[ -d "$CLAUDE_CONFIG_DIR" ]] && [[ ! -L "$CLAUDE_CONFIG_DIR" ]]; then
    if [[ "$NO_BACKUP" == "false" ]]; then
      print_error "Directory ~/.claude exists but was not backed up"
      print_info "Run with --no-backup to force removal, or remove manually"
      exit 1
    else
      print_warning "Removing existing ~/.claude directory"
      rm -rf "$CLAUDE_CONFIG_DIR"
    fi
  fi

  # Create symlinks with GNU Stow
  print_info "Creating symlinks with GNU Stow..."

  if stow -v claude 2>&1 | grep -q "LINK"; then
    print_success "Claude configuration symlinked: ~/.claude"
  else
    print_warning "No new symlinks created (may already exist)"
  fi

  # Verify symlink
  if [[ -L "$CLAUDE_CONFIG_DIR" ]]; then
    local target
    target=$(readlink "$CLAUDE_CONFIG_DIR")
    print_success "Verified: ~/.claude → $target"
  elif [[ -d "$CLAUDE_CONFIG_DIR" ]]; then
    print_success "Configuration directory exists: ~/.claude"
  else
    print_error "Failed to create ~/.claude"
    exit 1
  fi
}

# =============================================================================
# Profile Activation
# =============================================================================

activate_default_profile() {
  print_header "Activating Default Profile"

  local active_link="$PROFILES_DIR/active"
  local default_profile="$PROFILES_DIR/default"

  # Check if a profile is already active
  if [[ -L "$active_link" ]]; then
    local current
    current=$(readlink "$active_link")
    print_info "Profile already active: $current"
    return 0
  fi

  # Check if default profile exists
  if [[ ! -d "$default_profile" ]]; then
    print_warning "Default profile not found: $default_profile"
    print_info "Create a default profile or activate one manually"
    return 0
  fi

  # Activate default profile
  print_info "No active profile found, activating 'default'..."
  ln -s "default" "$active_link"
  print_success "Activated profile: default"
}

# =============================================================================
# Claude Code Installation
# =============================================================================

install_claude_code() {
  print_header "Installing Claude Code CLI"

  # Check if Claude Code is already installed
  if command_exists claude; then
    local claude_version
    claude_version=$(claude --version 2>&1 | head -n1 || echo "unknown")
    print_success "Claude Code already installed: $claude_version"

    if confirm "Update Claude Code to latest version?"; then
      if is_macos; then
        brew upgrade claude || print_warning "Failed to update (may already be latest)"
      elif is_linux; then
        # Check if package is installed in system directory (requires sudo)
        local pkg_path
        pkg_path=$(npm root -g 2>/dev/null)/@anthropic-ai/claude-code

        if [[ -d "$pkg_path" ]] && [[ ! -w "$pkg_path" ]]; then
          print_warning "Claude Code is installed globally and requires elevated permissions"
          if confirm "Use sudo to update?"; then
            sudo npm install -g @anthropic-ai/claude-code@latest
          else
            print_warning "Skipping update"
            return 0
          fi
        else
          npm install -g @anthropic-ai/claude-code@latest
        fi
      fi
      print_success "Claude Code updated"
    fi
    return 0
  fi

  # Claude Code not installed
  print_warning "Claude Code not installed"
  print_info "Claude Code is the official CLI for agentic coding with Claude"

  if ! confirm "Install Claude Code?"; then
    print_warning "Skipping Claude Code installation"
    print_info "You can install later with: scripts/install-claude-code.sh"
    return 0
  fi

  if is_macos; then
    print_info "Installing Claude Code via Homebrew..."

    if ! command_exists brew; then
      print_error "Homebrew not found. Please install Homebrew first:"
      print_info "Visit: https://brew.sh"
      return 1
    fi

    # Add Anthropic tap if not already added
    if ! brew tap | grep -q "anthropics/claude"; then
      brew tap anthropics/claude
    fi

    brew install claude
    print_success "Claude Code installed"

  elif is_linux; then
    print_info "Installing Claude Code via npm..."

    if ! command_exists npm; then
      print_error "npm is required to install Claude Code"
      print_info "Please install Node.js/npm first"
      return 1
    fi

    npm install -g @anthropic-ai/claude-code
    print_success "Claude Code installed"
  fi

  # Prompt for authentication
  echo ""
  print_info "Claude Code requires authentication with your Anthropic API key"
  if confirm "Run 'claude auth' now to authenticate?"; then
    claude auth
  else
    print_warning "Remember to run 'claude auth' before using Claude Code"
  fi
}

# =============================================================================
# MCP Configuration Deployment
# =============================================================================

deploy_mcp_config() {
  print_header "Deploying MCP Configuration"

  # Check if setup-mcp.sh exists
  if [[ ! -f "$SCRIPT_DIR/scripts/setup-mcp.sh" ]]; then
    print_error "MCP setup script not found: scripts/setup-mcp.sh"
    exit 1
  fi

  # Run MCP setup script
  print_info "Running MCP setup script..."
  bash "$SCRIPT_DIR/scripts/setup-mcp.sh"

  print_success "MCP configuration deployed"
}

# =============================================================================
# Validation
# =============================================================================

validate_installation() {
  print_header "Validating Installation"

  local validation_ok=true

  # Check ~/.claude exists
  if [[ -d "$CLAUDE_CONFIG_DIR" ]]; then
    print_success "~/.claude directory exists"
  else
    print_error "~/.claude directory not found"
    validation_ok=false
  fi

  # Check ~/.mcp.json exists
  if [[ -f "$MCP_CONFIG_FILE" ]]; then
    print_success "~/.mcp.json file exists"

    # Verify no unsubstituted variables
    if grep -q '${' "$MCP_CONFIG_FILE" 2>/dev/null; then
      print_warning "~/.mcp.json contains unsubstituted variables"
      print_info "Edit .env.mcp.local and run: scripts/setup-mcp.sh"
    else
      print_success "~/.mcp.json properly configured"
    fi
  else
    print_warning "~/.mcp.json not found"
    print_info "Run scripts/setup-mcp.sh to deploy MCP configuration"
  fi

  # Check Claude Code CLI
  if command_exists claude; then
    local claude_version
    claude_version=$(claude --version 2>&1 | head -n1 || echo "unknown")
    print_success "Claude Code CLI installed: $claude_version"
  else
    print_warning "Claude Code CLI not installed"
    print_info "Install with: scripts/install-claude-code.sh"
  fi

  # Check GNU Stow
  if command_exists stow; then
    print_success "GNU Stow installed"
  else
    print_error "GNU Stow not installed"
    validation_ok=false
  fi

  if [[ "$validation_ok" == "false" ]]; then
    print_error "Validation failed"
    return 1
  fi

  print_success "Installation validation passed"
  return 0
}

# =============================================================================
# Next Steps
# =============================================================================

show_next_steps() {
  print_header "Installation Complete"

  cat << EOF
${GREEN}✓${NC} Claude Code configuration installed successfully!

${BLUE}Next steps:${NC}

${YELLOW}1. Configure API keys (optional):${NC}
   ${BLUE}cd $SCRIPT_DIR${NC}
   ${BLUE}# Edit .env.mcp.local with your actual API keys${NC}
   ${BLUE}# Then run: ./scripts/setup-mcp.sh${NC}

   Note: 4 of 6 MCP servers work without API keys!

${YELLOW}2. Test Claude Code:${NC}
   ${BLUE}claude --version${NC}

${YELLOW}3. Verify MCP servers:${NC}
   ${BLUE}./scripts/list-mcp-tools.sh${NC}

${YELLOW}4. Start using Claude Code:${NC}
   ${BLUE}claude${NC}

${BLUE}For more information:${NC}
   • Documentation: ~/.claude/docs/
   • MCP servers: ~/.mcp.json
   • Add API keys: .env.mcp.local

${GREEN}Happy coding with Claude!${NC}

EOF
}

show_next_steps_configured() {
  print_header "Installation Complete"

  cat << EOF
${GREEN}✓${NC} Claude Code configuration installed successfully!

${BLUE}Next steps:${NC}

${YELLOW}1. Test Claude Code:${NC}
   ${BLUE}claude --version${NC}

${YELLOW}2. Verify MCP servers:${NC}
   ${BLUE}./scripts/list-mcp-tools.sh${NC}
   ${BLUE}# Or in Claude Code: /mcp${NC}

${YELLOW}3. Start using Claude Code:${NC}
   ${BLUE}claude${NC}

${BLUE}Configuration:${NC}
   • Claude config: ~/.claude/
   • MCP config: ~/.mcp.json
   • API keys: $SCRIPT_DIR/.env.mcp.local

${GREEN}Happy coding with Claude!${NC}

EOF
}

# =============================================================================
# Main Installation Flow
# =============================================================================

main() {
  # Parse command-line arguments
  parse_arguments "$@"

  # Print banner
  print_header "dotclaude Installation"
  print_info "Installing Claude Code configuration with MCP servers"
  print_info "Installation directory: $SCRIPT_DIR"
  echo ""

  # Detect OS
  local os
  os=$(detect_os)
  print_info "Detected OS: $os"

  if [[ "$os" == "unknown" ]]; then
    print_error "Unsupported operating system: $(uname -s)"
    print_info "This script supports macOS and Linux only"
    exit 1
  fi

  # Install dependencies
  if [[ "$SKIP_DEPS" == "true" ]]; then
    print_info "Skipping dependency installation (--skip-deps)"
    if ! check_dependencies; then
      print_error "Required dependencies missing"
      print_info "Remove --skip-deps flag to install dependencies"
      exit 1
    fi
  else
    install_dependencies
  fi

  # Backup existing configuration
  if [[ "$NO_BACKUP" == "true" ]]; then
    print_warning "Skipping backup (--no-backup)"
  else
    backup_existing_config
  fi

  # Install Claude configuration
  install_claude_config

  # Activate default profile if none active
  activate_default_profile

  # Install Claude Code CLI
  install_claude_code

  # Deploy MCP configuration
  # Always deploy MCP config (works even without API keys for some servers)
  deploy_mcp_config

  # Validate installation
  validate_installation

  # Show next steps
  if [[ -f "$SCRIPT_DIR/.env.mcp.local" ]] && [[ -f "$MCP_CONFIG_FILE" ]]; then
    show_next_steps_configured
  else
    show_next_steps
  fi
}

# =============================================================================
# Entry Point
# =============================================================================

main "$@"

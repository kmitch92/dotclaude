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
  print_info "  - MCP servers (context7, sequential-thinking, puppeteer, browser-tools, aws-cdk)"

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

install_bun() {
  print_info "Checking for Bun..."

  if command_exists bun; then
    print_success "Bun already installed: $(bun --version)"
    return 0
  fi

  print_warning "Bun not found"
  print_info "Bun is needed for:"
  print_info "  - claude-mem memory worker (runs on the bun runtime)"

  if ! confirm "Install Bun?"; then
    print_warning "Skipping Bun installation"
    print_info "Note: claude-mem's memory worker will not run without Bun"
    return 0
  fi

  # The official installer is cross-platform (macOS + Linux) and installs to
  # ~/.bun/bin; bun is not packaged in apt/dnf/pacman repos, so use it for all OSes.
  print_info "Installing Bun via official installer..."
  if curl -fsSL https://bun.sh/install | bash; then
    # Add bun to PATH for the remainder of the current install run.
    export PATH="$HOME/.bun/bin:$PATH"
    print_success "Bun installed"
  else
    print_warning "Bun installation failed"
    print_info "Note: claude-mem's memory worker will not run without Bun"
  fi
}

# =============================================================================
# uv (Astral) Installation
# =============================================================================

install_uv() {
  print_info "Checking for uv..."

  if command_exists uv; then
    print_success "uv already installed: $(uv --version)"
    return 0
  fi

  print_warning "uv not found"
  print_info "uv is needed for:"
  print_info "  - Headroom proxy (installed via 'uv tool install')"
  print_info "  - aws-cdk MCP server (run via uvx, which ships with uv)"

  if ! confirm "Install uv?"; then
    print_warning "Skipping uv installation"
    print_info "Note: Headroom and the aws-cdk MCP server will not be available without uv"
    return 0
  fi

  # The official installer is cross-platform (macOS + Linux) and installs to
  # ~/.local/bin; uv is not reliably packaged in distro repos, so use it for all OSes.
  print_info "Installing uv via official installer..."
  if curl -LsSf https://astral.sh/uv/install.sh | sh; then
    # Add uv to PATH for the remainder of the current install run.
    # uv installs to ~/.local/bin; older versions used ~/.cargo/bin.
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    print_success "uv installed"
  else
    print_warning "uv installation failed"
    print_info "Note: Headroom and the aws-cdk MCP server will not be available without uv"
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

  # Check Bun (optional but recommended for claude-mem memory worker)
  if ! command_exists bun; then
    print_warning "Bun not installed (needed for claude-mem memory worker)"
  else
    print_success "Bun installed: $(bun --version)"
  fi

  # Check uv (optional but recommended for Headroom and aws-cdk MCP via uvx)
  if ! command_exists uv; then
    print_warning "uv not installed (needed for Headroom and aws-cdk MCP server via uvx)"
  else
    print_success "uv installed: $(uv --version)"
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
  install_bun
  install_uv

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
    # Exclude runtime/cache state so the backup stays fast and small.
    backup_path=$(backup_dir_excluding "$CLAUDE_CONFIG_DIR" \
      backups cache debug file-history ide paste-cache projects \
      session-env sessions shell-snapshots statsig tasks todos \
      history.jsonl stats-cache.json mcp-needs-auth-cache.json '*.log')
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
# Claude Code Installation
# =============================================================================

install_claude_code() {
  source "$SCRIPT_DIR/scripts/install-claude-code.sh"
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
# Headroom Proxy Setup (optional)
# =============================================================================

setup_headroom_proxy() {
  print_header "Setting Up Headroom Proxy"

  # Optional step: skip gracefully if the script is not present.
  if [[ ! -f "$SCRIPT_DIR/scripts/install-headroom.sh" ]]; then
    print_info "Headroom setup script not found, skipping: scripts/install-headroom.sh"
    return 0
  fi

  # Run Headroom setup script (it is idempotent and self-guards on uv/headroom).
  print_info "Running Headroom setup script..."
  bash "$SCRIPT_DIR/scripts/install-headroom.sh"

  print_success "Headroom proxy setup complete"
}

# =============================================================================
# claude-mem Setup (optional)
# =============================================================================

setup_claude_mem() {
  print_header "Setting Up claude-mem"

  # Optional step: skip gracefully if the script is not present.
  if [[ ! -f "$SCRIPT_DIR/scripts/install-claude-mem.sh" ]]; then
    print_info "claude-mem setup script not found, skipping: scripts/install-claude-mem.sh"
    return 0
  fi

  # Run claude-mem setup script (it is idempotent and self-guards on the claude CLI).
  print_info "Running claude-mem setup script..."
  bash "$SCRIPT_DIR/scripts/install-claude-mem.sh"

  print_success "claude-mem setup complete"
}

# =============================================================================
# Serena Config Deployment (optional)
# =============================================================================

setup_serena() {
  print_header "Setting Up Serena Configuration"

  local serena_dir="$HOME/.serena"
  local serena_config="$serena_dir/serena_config.yml"
  local config_source="$SCRIPT_DIR/serena/serena_config.yml"

  if [[ ! -f "$config_source" ]]; then
    print_info "Serena config source not found, skipping: serena/serena_config.yml"
    return 0
  fi

  mkdir -p "$serena_dir"

  # Back up and remove any existing non-symlink config
  if [[ -f "$serena_config" ]] && [[ ! -L "$serena_config" ]]; then
    local backup_path
    backup_path=$(backup_file "$serena_config")
    print_info "Backed up existing serena_config.yml"
    rm -f "$serena_config"
  fi

  # Create or re-point symlink
  if [[ -L "$serena_config" ]]; then
    rm "$serena_config"
  fi

  ln -s "$config_source" "$serena_config"
  print_success "Serena config symlinked: ~/.serena/serena_config.yml → $config_source"
}

# =============================================================================
# claude-bare Launcher Deployment (optional)
# =============================================================================

setup_claude_bare() {
  print_header "Setting Up claude-bare Launcher"

  local launcher_source="$SCRIPT_DIR/bin/claude-bare"
  local local_bin="$HOME/.local/bin"
  local launcher_target="$local_bin/claude-bare"

  if [[ ! -f "$launcher_source" ]]; then
    print_info "claude-bare source not found, skipping: bin/claude-bare"
    return 0
  fi

  mkdir -p "$local_bin"

  # Ensure the launcher is executable
  chmod +x "$launcher_source"

  # Back up and remove any existing non-symlink launcher
  if [[ -f "$launcher_target" ]] && [[ ! -L "$launcher_target" ]]; then
    local backup_path
    backup_path=$(backup_file "$launcher_target")
    print_info "Backed up existing claude-bare"
    rm -f "$launcher_target"
  fi

  # Create or re-point symlink
  if [[ -L "$launcher_target" ]]; then
    rm "$launcher_target"
  fi

  ln -s "$launcher_source" "$launcher_target"
  print_success "claude-bare symlinked: ~/.local/bin/claude-bare → $launcher_source"
  print_info "Ensure ~/.local/bin is on your PATH to use 'claude-bare'"
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

  # Install Claude Code CLI
  install_claude_code

  # Deploy MCP configuration
  # Always deploy MCP config (works even without API keys for some servers)
  deploy_mcp_config

  # Set up Headroom proxy (optional; self-guards on prerequisites)
  setup_headroom_proxy

  # Set up claude-mem (optional; self-guards on the claude CLI)
  setup_claude_mem

  # Set up Serena config
  setup_serena

  # Set up claude-bare launcher (optional; self-guards on source presence)
  setup_claude_bare

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

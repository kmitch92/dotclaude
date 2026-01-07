#!/usr/bin/env bash

# =============================================================================
# CodeRAG Setup Script
# =============================================================================
# Handles initial installation and configuration of CodeRAG MCP server
# with Neo4j database for code knowledge graph storage.
#
# This script is idempotent - safe to run multiple times.
#
# Usage: ./scripts/setup-coderag.sh
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# Get the directory where this script's parent (dotfiles) is located
readonly DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source utilities
source "$DOTFILES_DIR/scripts/utils.sh"

print_header "Setting up CodeRAG MCP Server"

# =============================================================================
# Check Prerequisites
# =============================================================================

check_prerequisites() {
  print_info "Checking prerequisites..."

  local prerequisites_met=true

  # Check for Docker
  if ! command_exists docker; then
    print_warning "Docker is not installed"
    print_info "Install Docker from: https://docs.docker.com/get-docker/"
    print_info "Docker is required to run Neo4j database for CodeRAG"
    echo ""
    if ! confirm "Continue setup without Docker? (You'll need to install it later)"; then
      print_error "Docker is required. Please install it and try again."
      exit 1
    fi
    print_warning "Continuing without Docker - you must install it before using CodeRAG"
  else
    print_success "Docker is installed"

    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
      print_warning "Docker daemon is not running"
      print_info "Start Docker Desktop or run: sudo systemctl start docker"
      print_info "Docker must be running before you can use CodeRAG"
    else
      print_success "Docker daemon is running"
    fi
  fi

  # Check for Node.js/npm
  if ! command_exists node; then
    print_error "Node.js is not installed"
    print_info "Install Node.js from: https://nodejs.org/"
    prerequisites_met=false
  else
    print_success "Node.js is installed ($(node --version))"
  fi

  if ! command_exists npm; then
    print_error "npm is not installed"
    print_info "npm should come with Node.js installation"
    prerequisites_met=false
  else
    print_success "npm is installed ($(npm --version))"
  fi

  # Check for git
  if ! command_exists git; then
    print_error "Git is not installed"
    print_info "Install Git from: https://git-scm.com/"
    prerequisites_met=false
  else
    print_success "Git is installed"
  fi

  # Exit if critical prerequisites not met
  if [[ "$prerequisites_met" == "false" ]]; then
    echo ""
    print_error "Prerequisites not met. Please install missing dependencies and try again."
    exit 1
  fi

  echo ""
}

# =============================================================================
# Initialize Git Submodule
# =============================================================================

init_submodule() {
  print_info "Checking CodeRAG submodule..."

  local coderag_dir="$DOTFILES_DIR/vendor/coderag"

  if [[ ! -d "$coderag_dir/.git" ]] && [[ ! -f "$coderag_dir/package.json" ]]; then
    print_info "Initializing CodeRAG submodule..."
    cd "$DOTFILES_DIR"
    git submodule update --init vendor/coderag
    print_success "CodeRAG submodule initialized"
  else
    print_success "CodeRAG submodule already initialized"

    # Check if submodule needs update
    cd "$DOTFILES_DIR"
    if git submodule status vendor/coderag | grep -q '^+'; then
      print_info "Submodule has updates available"
      if confirm "Update CodeRAG submodule to latest?"; then
        git submodule update --remote vendor/coderag
        print_success "CodeRAG submodule updated"
      fi
    fi
  fi

  echo ""
}

# =============================================================================
# Build CodeRAG
# =============================================================================

build_coderag() {
  local coderag_dir="$DOTFILES_DIR/vendor/coderag"

  # Check if already built
  if [[ -d "$coderag_dir/build" ]]; then
    print_success "CodeRAG already built"
    return 0
  fi

  print_info "Building CodeRAG..."

  cd "$coderag_dir"

  # Install dependencies
  print_info "Installing npm dependencies..."
  npm install

  # Build TypeScript
  print_info "Building TypeScript..."
  npm run build

  print_success "CodeRAG built successfully"
  echo ""
}

# =============================================================================
# Create Data Directory
# =============================================================================

create_data_directory() {
  print_info "Setting up Neo4j data directory..."

  local neo4j_data_dir="$HOME/neo4j-coderag"

  ensure_directory "$neo4j_data_dir/data"
  ensure_directory "$neo4j_data_dir/logs"
  ensure_directory "$neo4j_data_dir/plugins"

  print_success "Neo4j data directory ready at: $neo4j_data_dir"
  echo ""
}

# =============================================================================
# Configure Neo4j Password
# =============================================================================

configure_password() {
  print_info "Checking CodeRAG password configuration..."

  local env_file="$DOTFILES_DIR/.env.mcp.local"

  # Create .env.mcp.local from template if it doesn't exist
  if [[ ! -f "$env_file" ]]; then
    print_info "Creating .env.mcp.local from template..."
    cp "$DOTFILES_DIR/.env.mcp" "$env_file"
  fi

  # Check if password is already configured
  local current_password=""
  if grep -q "CODERAG_NEO4J_PASSWORD=" "$env_file" 2>/dev/null; then
    current_password=$(grep "CODERAG_NEO4J_PASSWORD=" "$env_file" | cut -d'=' -f2)
  fi

  if [[ -n "$current_password" ]] && [[ "$current_password" != "your_neo4j_password_here" ]]; then
    print_success "CodeRAG password already configured"
    return 0
  fi

  # Prompt for password
  echo ""
  print_info "Neo4j requires a password for the database."
  print_info "Choose a secure password (min 8 characters)."
  echo ""

  local password=""
  while [[ -z "$password" ]] || [[ ${#password} -lt 8 ]]; do
    read -rsp "Enter Neo4j password: " password
    echo ""
    if [[ ${#password} -lt 8 ]]; then
      print_warning "Password must be at least 8 characters"
    fi
  done

  # Update .env.mcp.local
  if grep -q "CODERAG_NEO4J_PASSWORD=" "$env_file"; then
    # Replace existing - use different delimiter for sed since password might contain /
    sed -i.bak "s|CODERAG_NEO4J_PASSWORD=.*|CODERAG_NEO4J_PASSWORD=$password|" "$env_file"
    rm -f "$env_file.bak"
  else
    # Append
    echo "CODERAG_NEO4J_PASSWORD=$password" >> "$env_file"
  fi

  print_success "Password configured in .env.mcp.local"
  echo ""
}

# =============================================================================
# Show Next Steps
# =============================================================================

show_next_steps() {
  print_success "CodeRAG setup complete!"
  echo ""
  print_info "Next steps:"
  echo ""
  echo "  1. Start Neo4j container:"
  echo "     ./scripts/start-neo4j.sh"
  echo ""
  echo "  2. Restart Claude Code to load MCP servers"
  echo ""
  echo "  3. Use CodeRAG tools in Claude Code:"
  echo "     - coderag_index_codebase: Index a project"
  echo "     - coderag_query: Query code knowledge"
  echo "     - coderag_analyze: Analyze code relationships"
  echo ""
  print_info "Documentation: vendor/coderag/README.md"
  echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
  check_prerequisites
  init_submodule
  build_coderag
  create_data_directory
  configure_password
  show_next_steps
}

main

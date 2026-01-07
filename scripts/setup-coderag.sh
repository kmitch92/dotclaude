#!/bin/bash

# =============================================================================
# CodeRAG Setup Script
# =============================================================================
# Handles initial installation and configuration of CodeRAG MCP server
# with Neo4j database for code knowledge graph storage.
#
# Usage: ./scripts/setup-coderag.sh
# =============================================================================

set -e

# Get the directory where this script's parent (dotfiles) is located
DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Source utilities
source "$DOTFILES_DIR/scripts/utils.sh"

print_header "Setting up CodeRAG MCP Server"

# =============================================================================
# Check Prerequisites
# =============================================================================

print_info "Checking prerequisites..."

PREREQUISITES_MET=true

# Check for Docker
if ! command_exists docker; then
    print_error "Docker is not installed"
    print_info "Install Docker from: https://docs.docker.com/get-docker/"
    PREREQUISITES_MET=false
else
    print_success "Docker is installed"

    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running"
        print_info "Start Docker Desktop or run: sudo systemctl start docker"
        PREREQUISITES_MET=false
    else
        print_success "Docker daemon is running"
    fi
fi

# Check for Node.js/npm
if ! command_exists node; then
    print_error "Node.js is not installed"
    print_info "Install Node.js from: https://nodejs.org/"
    PREREQUISITES_MET=false
else
    print_success "Node.js is installed ($(node --version))"
fi

if ! command_exists npm; then
    print_error "npm is not installed"
    print_info "npm should come with Node.js installation"
    PREREQUISITES_MET=false
else
    print_success "npm is installed ($(npm --version))"
fi

# Check for git
if ! command_exists git; then
    print_error "Git is not installed"
    print_info "Install Git from: https://git-scm.com/"
    PREREQUISITES_MET=false
else
    print_success "Git is installed"
fi

# Exit if prerequisites not met
if [ "$PREREQUISITES_MET" = false ]; then
    echo ""
    print_error "Prerequisites not met. Please install missing dependencies and try again."
    exit 1
fi

echo ""

# =============================================================================
# Initialize Git Submodule
# =============================================================================

print_info "Checking CodeRAG submodule..."

CODERAG_DIR="$DOTFILES_DIR/vendor/coderag"

if [ ! -d "$CODERAG_DIR" ] || [ ! -f "$CODERAG_DIR/package.json" ]; then
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

# =============================================================================
# Build CodeRAG
# =============================================================================

print_info "Building CodeRAG..."

cd "$CODERAG_DIR"

# Install dependencies
print_info "Installing npm dependencies..."
npm install

# Build TypeScript
print_info "Building TypeScript..."
npm run build

print_success "CodeRAG built successfully"

echo ""

# =============================================================================
# Create Data Directory
# =============================================================================

print_info "Setting up Neo4j data directory..."

NEO4J_DATA_DIR="$HOME/neo4j-coderag"

ensure_directory "$NEO4J_DATA_DIR/data"
ensure_directory "$NEO4J_DATA_DIR/logs"
ensure_directory "$NEO4J_DATA_DIR/plugins"

print_success "Neo4j data directory created at: $NEO4J_DATA_DIR"

echo ""

# =============================================================================
# Check Environment Configuration
# =============================================================================

print_info "Checking environment configuration..."

ENV_LOCAL="$DOTFILES_DIR/.env.mcp.local"

if [ ! -f "$ENV_LOCAL" ]; then
    print_warning ".env.mcp.local not found"
    print_info "Create it from template: cp .env.mcp .env.mcp.local"
    PASSWORD_CONFIGURED=false
else
    # Check if CODERAG_NEO4J_PASSWORD is configured
    if grep -q "^CODERAG_NEO4J_PASSWORD=" "$ENV_LOCAL"; then
        PASSWORD_VALUE=$(grep "^CODERAG_NEO4J_PASSWORD=" "$ENV_LOCAL" | cut -d'=' -f2-)
        if [ -z "$PASSWORD_VALUE" ] || [ "$PASSWORD_VALUE" = "your_neo4j_password_here" ]; then
            print_warning "CODERAG_NEO4J_PASSWORD is not configured in .env.mcp.local"
            PASSWORD_CONFIGURED=false
        else
            print_success "CODERAG_NEO4J_PASSWORD is configured"
            PASSWORD_CONFIGURED=true
        fi
    else
        print_warning "CODERAG_NEO4J_PASSWORD not found in .env.mcp.local"
        print_info "Add: CODERAG_NEO4J_PASSWORD=your_secure_password"
        PASSWORD_CONFIGURED=false
    fi
fi

if [ "$PASSWORD_CONFIGURED" = false ]; then
    echo ""
    print_warning "Neo4j password not configured!"
    print_info "You must set CODERAG_NEO4J_PASSWORD in .env.mcp.local before starting Neo4j"
    print_info "Example: CODERAG_NEO4J_PASSWORD=MySecurePassword123"
fi

echo ""

# =============================================================================
# Next Steps
# =============================================================================

print_success "CodeRAG setup complete!"
echo ""
print_info "Next steps:"
echo ""
echo "  1. Configure password in .env.mcp.local:"
echo "     CODERAG_NEO4J_PASSWORD=your_secure_password"
echo ""
echo "  2. Start Neo4j container:"
echo "     ./scripts/start-neo4j.sh"
echo ""
echo "  3. Run MCP setup to include CodeRAG:"
echo "     ./scripts/setup-mcp.sh"
echo ""
echo "  4. Restart Claude Code to load MCP servers"
echo ""
echo "  5. Use CodeRAG tools in Claude Code:"
echo "     - coderag_index_codebase: Index a project"
echo "     - coderag_query: Query code knowledge"
echo "     - coderag_analyze: Analyze code relationships"
echo ""
print_info "Documentation: vendor/coderag/README.md"
echo ""

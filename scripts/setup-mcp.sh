#!/bin/bash

# =============================================================================
# MCP Server Configuration Setup
# =============================================================================
# Substitutes environment variables from .env.mcp.local into .mcp.json template
# and deploys to home directory
#
# Usage: ./scripts/setup-mcp.sh
# =============================================================================

set -e

# Get the directory where this script's parent (dotfiles) is located
DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Source utilities
source "$DOTFILES_DIR/scripts/utils.sh"

print_header "Setting up MCP Server Configuration"

# =============================================================================
# Validate runtime tool dependencies
# =============================================================================

print_info "Checking for required runtime tools..."

# Track missing tools
MISSING_TOOLS=()

# Check for npx (Node.js/npm)
if ! command -v npx &> /dev/null; then
    MISSING_TOOLS+=("npx (Node.js/npm)")
fi

# Check for uvx (Python/uv)
if ! command -v uvx &> /dev/null; then
    MISSING_TOOLS+=("uvx (Python/uv)")
fi

# Check for docker (for coderag)
if ! command -v docker &> /dev/null; then
    MISSING_TOOLS+=("docker (for coderag)")
fi

# If tools are missing, warn but continue
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    print_warning "Some runtime tools are missing:"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "  ✗ $tool"
    done
    echo ""
    print_info "Affected MCP servers:"
    if [[ " ${MISSING_TOOLS[@]} " =~ "npx" ]]; then
        echo "  - context7, sequential-thinking, playwright (require npx)"
    fi
    if [[ " ${MISSING_TOOLS[@]} " =~ "uvx" ]]; then
        echo "  - aws-core, aws-cdk (require uvx)"
    fi
    if [[ " ${MISSING_TOOLS[@]} " =~ "docker" ]]; then
        echo "  - coderag (requires docker)"
    fi
    echo ""
    print_info "Config will be deployed but these servers won't work until tools are installed"
    print_info "To install: Install Node.js/npm for npx, or Python/uv for uvx"
    echo ""
else
    print_success "All required runtime tools found"
fi

# =============================================================================
# Check for .env.mcp.local
# =============================================================================

if [ ! -f "$DOTFILES_DIR/.env.mcp.local" ]; then
    print_warning ".env.mcp.local not found"
    print_info "Creating from template..."

    cp "$DOTFILES_DIR/.env.mcp" "$DOTFILES_DIR/.env.mcp.local"
    print_success "Created .env.mcp.local from template"

    print_info "Note: Using placeholder API keys - some servers may not work"
    print_info "Edit .env.mcp.local and re-run setup-mcp.sh to enable all servers"
    echo ""
fi

# =============================================================================
# Source environment variables
# =============================================================================

print_info "Loading environment variables from .env.mcp.local..."
set -a  # Automatically export all variables
source "$DOTFILES_DIR/.env.mcp.local"
set +a  # Disable automatic export

# Validate environment variables (all are optional - warn but don't fail)
MISSING_KEYS=()

# Check CONTEXT7_API_KEY
if [ "$CONTEXT7_API_KEY" = "your_api_key_here" ] || [ -z "$CONTEXT7_API_KEY" ]; then
    print_warning "CONTEXT7_API_KEY not configured - context7 server will not be available"
    print_info "To enable context7 later: Add CONTEXT7_API_KEY to .env.mcp.local and re-run setup-mcp.sh"
    print_info "  • Get key from: https://console.upstash.com"
    MISSING_KEYS+=("CONTEXT7_API_KEY")
    # Set empty value so envsubst doesn't fail
    export CONTEXT7_API_KEY=""
fi

# Check ANTHROPIC_API_KEY
if [ "$ANTHROPIC_API_KEY" = "your_anthropic_api_key_here" ] || [ -z "$ANTHROPIC_API_KEY" ]; then
    print_warning "ANTHROPIC_API_KEY not configured - taskmaster server will not be available"
    print_info "To enable taskmaster later: Add ANTHROPIC_API_KEY to .env.mcp.local and re-run setup-mcp.sh"
    MISSING_KEYS+=("ANTHROPIC_API_KEY")
    # Set empty value so envsubst doesn't fail
    export ANTHROPIC_API_KEY=""
fi

# Check CODERAG_NEO4J_PASSWORD
if [ "$CODERAG_NEO4J_PASSWORD" = "your_neo4j_password_here" ] || [ -z "$CODERAG_NEO4J_PASSWORD" ]; then
    print_warning "CODERAG_NEO4J_PASSWORD not configured - coderag server will not be available"
    print_info "To enable coderag later: Add CODERAG_NEO4J_PASSWORD to .env.mcp.local and re-run setup-mcp.sh"
    print_info "  • Setup guide: ./docs/coderag-setup.md"
    MISSING_KEYS+=("CODERAG_NEO4J_PASSWORD")
    export CODERAG_NEO4J_PASSWORD=""
fi

# Show what will work without API keys
if [ ${#MISSING_KEYS[@]} -gt 0 ]; then
    echo ""
    print_info "The following MCP servers will be available without additional configuration:"
    echo "  ✓ sequential-thinking (no key required)"
    echo "  ✓ playwright (no key required)"
    echo "  ✓ aws-core (uses AWS credentials)"
    echo "  ✓ aws-cdk (uses AWS credentials)"
    echo ""
    print_info "The following require configuration:"
    echo "  ✗ context7 (needs CONTEXT7_API_KEY)"
    echo "  ✗ taskmaster (needs ANTHROPIC_API_KEY)"
    echo "  ✗ coderag (needs CODERAG_NEO4J_PASSWORD + docker)"
    echo ""
fi

# =============================================================================
# Generate .mcp.json from template
# =============================================================================

print_info "Generating ~/.mcp.json from template..."

# Remove existing symlink if present (should be a generated file, not a symlink)
if [ -L "$HOME/.mcp.json" ]; then
    print_warning "Found symlink at ~/.mcp.json, removing..."
    rm "$HOME/.mcp.json"
    print_info "Symlink removed (will generate proper file)"
fi

# Check if envsubst is available
if ! command -v envsubst &> /dev/null; then
    print_warning "envsubst not found, attempting to install gettext..."
    
    if is_macos; then
        brew install gettext
        # Add gettext to PATH for this session
        export PATH="/usr/local/opt/gettext/bin:$PATH"
    elif is_linux; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y gettext-base
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y gettext
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm gettext
        else
            print_error "Could not install gettext. Please install it manually."
            exit 1
        fi
    fi
fi

# First resolve DOTFILES_DIR path, then substitute env vars
# DOTFILES_DIR is a shell variable, not an env var - resolve it before envsubst
sed "s|\${DOTFILES_DIR}|$DOTFILES_DIR|g" "$DOTFILES_DIR/mcp/mcp.json.template" | envsubst > "$HOME/.mcp.json"

print_success "MCP configuration deployed to ~/.mcp.json"

# =============================================================================
# Verify configuration
# =============================================================================

print_info "Verifying configuration..."

if [ -f "$HOME/.mcp.json" ]; then
    # Check that env vars were substituted (no ${VAR} patterns remaining)
    if grep -q '${' "$HOME/.mcp.json"; then
        print_warning "Some environment variables may not have been substituted"
        print_info "Please check $HOME/.mcp.json for any remaining \${VAR} patterns"
    else
        print_success "All environment variables substituted successfully"
    fi
    
    # Show configured servers
    echo ""
    print_info "Configured MCP servers:"
    if command -v jq &> /dev/null; then
        jq -r '.mcpServers | keys[]' "$HOME/.mcp.json" | while read server; do
            echo "  - $server"
        done
    else
        grep '"' "$HOME/.mcp.json" | grep ':' | head -10 | sed 's/.*"\(.*\)".*/  - \1/'
    fi
else
    print_error "Failed to create ~/.mcp.json"
    exit 1
fi

# =============================================================================
# Next steps
# =============================================================================

echo ""
print_success "MCP setup complete!"
print_info "Next steps:"
print_info "  1. Restart Claude Code to load new MCP servers"
print_info "  2. Verify with: /mcp command in Claude Code"
print_info "  3. Check logs if servers don't load: ~/.claude/logs/"
echo ""

#!/bin/bash

# =============================================================================
# MCP Server Registration
# =============================================================================
# Renders mcp/mcp.json.template with variables from .env.mcp.local (in memory)
# and registers each server at user scope with the claude CLI:
#   claude mcp remove --scope user <name>   (failure ignored)
#   claude mcp add-json --scope user <name> '<server json>'
# context7 is skipped when CONTEXT7_API_KEY is unset or the placeholder.
# Never writes ~/.mcp.json.
#
# Usage: ./scripts/setup-mcp.sh
# =============================================================================

set -e

# Get the directory where this script's parent (dotfiles) is located
DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Source utilities
source "$DOTFILES_DIR/scripts/utils.sh"

print_header "Registering MCP Servers"

if ! command_exists claude; then
    print_error "claude CLI not found on PATH - install Claude Code first, then re-run setup-mcp.sh"
    exit 1
fi

if ! command_exists jq; then
    print_error "jq not found on PATH - install jq, then re-run setup-mcp.sh"
    exit 1
fi

# =============================================================================
# Validate runtime tool dependencies
# =============================================================================

print_info "Checking for required runtime tools..."

# Track missing tools
MISSING_TOOLS=()

# Check for npx (Node.js/npm)
if ! command_exists npx; then
    MISSING_TOOLS+=("npx (Node.js/npm)")
fi

# Check for uvx (Python/uv)
if ! command_exists uvx; then
    MISSING_TOOLS+=("uvx (Python/uv)")
fi

# If tools are missing, warn but continue
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    print_warning "Some runtime tools are missing:"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "  ✗ $tool"
    done
    echo ""
    print_info "Affected MCP servers:"
    if [[ " ${MISSING_TOOLS[*]} " =~ "npx" ]]; then
        echo "  - context7, puppeteer (require npx)"
    fi
    if [[ " ${MISSING_TOOLS[*]} " =~ "uvx" ]]; then
        echo "  - aws-cdk, aws-documentation (require uvx)"
    fi
    echo ""
    print_info "Servers will be registered but won't start until these tools are installed"
    print_info "To install: Install Node.js/npm for npx, or Python/uv for uvx"
    echo ""
else
    print_success "All required runtime tools found"
fi

# =============================================================================
# Load .env.mcp.local
# =============================================================================

if [ ! -f "$DOTFILES_DIR/.env.mcp.local" ] && [ -f "$DOTFILES_DIR/.env.mcp" ]; then
    print_warning ".env.mcp.local not found"
    print_info "Creating from template..."
    cp "$DOTFILES_DIR/.env.mcp" "$DOTFILES_DIR/.env.mcp.local"
    print_success "Created .env.mcp.local from template"
    print_info "Edit .env.mcp.local and re-run setup-mcp.sh to enable all servers"
    echo ""
fi

if [ -f "$DOTFILES_DIR/.env.mcp.local" ]; then
    print_info "Loading environment variables from .env.mcp.local..."
    set -a  # Automatically export all variables
    source "$DOTFILES_DIR/.env.mcp.local"
    set +a  # Disable automatic export
else
    print_warning ".env.mcp.local not found - servers needing API keys will be skipped"
fi

CONTEXT7_ENABLED=true
if [ "${CONTEXT7_API_KEY:-}" = "your_api_key_here" ] || [ -z "${CONTEXT7_API_KEY:-}" ]; then
    CONTEXT7_ENABLED=false
    print_warning "CONTEXT7_API_KEY not configured - context7 server will not be registered"
    print_info "To enable context7 later: Add CONTEXT7_API_KEY to .env.mcp.local and re-run setup-mcp.sh"
    print_info "  • Get key from: https://console.upstash.com"
    # Set empty value so envsubst doesn't leave the placeholder
    export CONTEXT7_API_KEY=""
    echo ""
    print_info "The following MCP servers will be available without API keys:"
    echo "  ✓ puppeteer (no key required)"
    echo "  ✓ aws-cdk (uses AWS credentials)"
    echo "  ✓ aws-documentation (no key required)"
    echo ""
fi

# =============================================================================
# Render template
# =============================================================================

# Check if envsubst is available
if ! command_exists envsubst; then
    print_warning "envsubst not found, attempting to install gettext..."

    if is_macos; then
        brew install gettext
        # Add gettext to PATH for this session
        export PATH="/usr/local/opt/gettext/bin:$PATH"
    elif is_linux; then
        if command_exists apt-get; then
            sudo apt-get install -y gettext-base
        elif command_exists dnf; then
            sudo dnf install -y gettext
        elif command_exists pacman; then
            sudo pacman -S --noconfirm gettext
        else
            print_error "Could not install gettext. Please install it manually."
            exit 1
        fi
    fi
fi

RENDERED="$(envsubst < "$DOTFILES_DIR/mcp/mcp.json.template")"

if ! printf '%s' "$RENDERED" | jq -e '.mcpServers | type == "object"' > /dev/null 2>&1; then
    print_error "Rendered mcp/mcp.json.template is not valid JSON with an mcpServers object"
    exit 1
fi

if printf '%s' "$RENDERED" | grep -q '\${'; then
    print_warning "Some environment variables may not have been substituted - check .env.mcp.local"
fi

# =============================================================================
# Register servers
# =============================================================================

print_info "Registering MCP servers at user scope..."

REGISTERED=()
FAILED=()
SERVER_NAMES="$(printf '%s' "$RENDERED" | jq -r '.mcpServers | keys[]')"

while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ "$name" = "context7" ] && [ "$CONTEXT7_ENABLED" != true ]; then
        print_info "Skipping context7 (no CONTEXT7_API_KEY)"
        continue
    fi
    server_json="$(printf '%s' "$RENDERED" | jq -c --arg n "$name" '.mcpServers[$n]')"
    # Remove first so re-runs replace a stale definition; absent server is fine.
    claude mcp remove --scope user "$name" < /dev/null > /dev/null 2>&1 || true
    if claude mcp add-json --scope user "$name" "$server_json" < /dev/null > /dev/null; then
        REGISTERED+=("$name")
        print_success "Registered $name"
    else
        FAILED+=("$name")
        print_error "Failed to register $name"
    fi
done <<< "$SERVER_NAMES"

# =============================================================================
# Next steps
# =============================================================================

echo ""
if [ ${#FAILED[@]} -gt 0 ]; then
    print_error "MCP setup finished with failures: ${FAILED[*]}"
    exit 1
fi

print_success "MCP setup complete! Registered: ${REGISTERED[*]:-none}"
print_info "Next steps:"
print_info "  1. Restart Claude Code to load new MCP servers"
print_info "  2. Verify with: claude mcp list (or /mcp in Claude Code)"
print_info "  3. Check logs if servers don't load: ~/.claude/logs/"
echo ""

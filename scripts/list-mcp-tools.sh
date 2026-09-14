#!/bin/bash

# =============================================================================
# MCP Tool Discovery Script
# =============================================================================
# Lists all available MCP tools from configured servers
#
# Usage: ./scripts/list-mcp-tools.sh
# =============================================================================

set -e

# Get the directory where this script's parent (dotfiles) is located
DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Source utilities
source "$DOTFILES_DIR/scripts/utils.sh"

print_header "MCP Tool Discovery"

# =============================================================================
# Check Prerequisites
# =============================================================================

# Check if ~/.mcp.json exists
if [ ! -f "$HOME/.mcp.json" ]; then
    print_error "~/.mcp.json not found"
    print_info "Run ./scripts/setup-mcp.sh to configure MCP servers first"
    exit 1
fi

# Check if jq is available for JSON parsing
if ! command -v jq &> /dev/null; then
    print_warning "jq not found, attempting to install..."

    if is_macos; then
        brew install jq
    elif is_linux; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y jq
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y jq
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm jq
        else
            print_error "Could not install jq. Please install it manually."
            exit 1
        fi
    fi
fi

# =============================================================================
# Parse Configured Servers
# =============================================================================

print_info "Configured MCP servers:"
echo ""

# Extract server names from ~/.mcp.json
servers=$(jq -r '.mcpServers | keys[]' "$HOME/.mcp.json")

for server in $servers; do
    command=$(jq -r ".mcpServers.\"$server\".command" "$HOME/.mcp.json")
    args=$(jq -r ".mcpServers.\"$server\".args | @json" "$HOME/.mcp.json")

    echo "  ✓ $server"
    echo "    Command: $command ${args//\"/}"
done

echo ""

# =============================================================================
# Known MCP Tool Patterns
# =============================================================================

print_info "Known MCP tool naming patterns:"
echo ""
echo "Based on MCP naming conventions, tools follow the pattern:"
echo "  mcp__<server-name>__<tool-name>"
echo ""

# =============================================================================
# Tool Discovery by Server
# =============================================================================

print_header "Available MCP Tools by Server"
echo ""

print_info "Note: This script lists expected tool names based on server capabilities."
print_info "Run 'claude /mcp' in Claude Code for the authoritative list of available tools."
echo ""

# Context7 Tools (Documentation)
if echo "$servers" | grep -q "context7"; then
    print_success "Context7 (Documentation Lookup)"
    echo "  • mcp__context7__resolve-library-id"
    echo "  • mcp__context7__get-library-docs"
    echo ""
fi

# Puppeteer Tools (Browser Automation)
if echo "$servers" | grep -q "puppeteer"; then
    print_success "Puppeteer (Browser Automation)"
    echo "  • mcp__puppeteer__puppeteer_navigate"
    echo "  • mcp__puppeteer__puppeteer_screenshot"
    echo "  • mcp__puppeteer__puppeteer_click"
    echo "  • mcp__puppeteer__puppeteer_fill"
    echo "  • mcp__puppeteer__puppeteer_select"
    echo "  • mcp__puppeteer__puppeteer_hover"
    echo "  • mcp__puppeteer__puppeteer_evaluate"
    echo ""
fi

# AWS CDK Tools
if echo "$servers" | grep -q "aws-cdk"; then
    print_success "AWS CDK (Infrastructure as Code)"
    echo "  • mcp__aws-cdk__[tools require runtime query]"
    echo "  Note: Run 'claude /mcp' to see exact AWS CDK tools"
    echo ""
fi

# AWS Documentation Tools
if echo "$servers" | grep -q "aws-documentation"; then
    print_success "AWS Documentation (Docs Search & Retrieval)"
    echo "  • mcp__aws-documentation__search_documentation"
    echo "  • mcp__aws-documentation__read_documentation"
    echo "  • mcp__aws-documentation__read_sections"
    echo "  • mcp__aws-documentation__recommend"
    echo ""
fi

# =============================================================================
# Next Steps
# =============================================================================

print_header "Complete Tool Discovery"
echo ""
print_info "To get the authoritative list of all available MCP tools:"
echo "  1. Ensure Claude Code is running and authenticated"
echo "  2. Run: claude /mcp"
echo "  3. Or in Claude Code session, type: /mcp"
echo ""
print_info "This will show all tools with their exact names and parameters."
echo ""

#!/bin/bash

# =============================================================================
# Claude Code Installation
# =============================================================================
# Installs the Claude Code CLI for agentic coding

print_header "Installing Claude Code"

if command_exists claude; then
    CLAUDE_VERSION=$(claude --version 2>&1 | head -n1)
    print_success "Claude Code found: $CLAUDE_VERSION"

    echo ""
    if confirm "Update Claude Code to latest version?"; then
        if is_macos; then
            brew upgrade --cask claude-code
            print_success "Claude Code updated"
        elif is_linux; then
            print_info "Updating Claude Code..."

            # Check if package is installed in system directory (requires sudo)
            local pkg_path
            pkg_path=$(npm root -g 2>/dev/null)/@anthropic-ai/claude-code

            if [[ -d "$pkg_path" ]] && [[ ! -w "$pkg_path" ]]; then
                print_warning "Claude Code is installed globally and requires elevated permissions"
                if confirm "Use sudo to update?"; then
                    sudo npm install -g @anthropic-ai/claude-code@latest
                    print_success "Claude Code updated"
                else
                    print_warning "Skipping update"
                fi
            else
                npm install -g @anthropic-ai/claude-code@latest
                print_success "Claude Code updated"
            fi
        fi
    fi
else
    print_warning "Claude Code not installed"
    print_info "Claude Code is a CLI tool for agentic coding with Claude"
    print_info "Documentation: https://docs.claude.com/claude-code"
    echo ""
    
    if confirm "Install Claude Code?"; then
        if is_macos; then
            print_info "Installing via Homebrew..."

            brew install --cask claude-code
            print_success "Claude Code installed"
            
        elif is_linux; then
            print_info "Installing via npm..."

            if ! command_exists npm; then
                print_error "npm is required to install Claude Code"
                print_info "Please install Node.js and npm first"
                return 1
            fi

            npm install -g @anthropic-ai/claude-code
            print_success "Claude Code installed"
        fi
        
        # Setup and authentication
        echo ""
        print_info "Claude Code requires authentication"
        if confirm "Run 'claude auth' now to authenticate?"; then
            claude auth
        else
            print_warning "Remember to run 'claude auth' before using Claude Code"
        fi
    fi
fi

# Optional: Check for Claude Code extensions
if command_exists claude; then
    echo ""
    if confirm "Install recommended Claude Code extensions?"; then
        print_info "Installing recommended extensions..."
        
        # MCP servers and tools
        claude install mcp-server-filesystem
        claude install mcp-server-git
        
        print_success "Extensions installed"
    fi
fi

echo ""
print_success "Claude Code setup complete"

#!/bin/bash

# =============================================================================
# Claude Code Installation
# =============================================================================
# Installs the Claude Code CLI for agentic coding
#
# This script is sourced by install.sh (which sources utils.sh first).
# Guard: source utils.sh ourselves if detection functions are not loaded.

if ! declare -F detect_claude_install_method >/dev/null 2>&1; then
    _INSTALL_CLAUDE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=utils.sh
    source "${_INSTALL_CLAUDE_SCRIPT_DIR}/utils.sh"
fi

print_header "Installing Claude Code"

if command_exists claude; then
    CLAUDE_VERSION=$(claude --version 2>&1 | head -n1)
    print_success "Claude Code found: $CLAUDE_VERSION"

    echo ""
    if confirm "Update Claude Code to latest version?"; then
        # Detect how claude was installed and get the right update command
        _claude_bin="$(command -v claude)"
        _install_method="$(detect_claude_install_method "$_claude_bin")"
        _current_os="$(detect_os)"
        print_info "Detected install method: $_install_method"

        if _update_cmd="$(get_claude_update_command "$_install_method" "$_current_os")"; then
            # For npm updates, check if system directory requires sudo
            if [[ "$_install_method" == "npm" ]]; then
                _pkg_path=$(npm root -g 2>/dev/null)/@anthropic-ai/claude-code

                if [[ -d "$_pkg_path" ]] && [[ ! -w "$_pkg_path" ]]; then
                    print_warning "Claude Code is installed globally and requires elevated permissions"
                    if confirm "Use sudo to update?"; then
                        # Resolve absolute path to npm so sudo (especially
                        # sudo-rs) can find it outside the user's PATH.
                        _npm_abs="$(command -v npm)"
                        sudo "$_npm_abs" install -g @anthropic-ai/claude-code@latest
                    else
                        print_warning "Skipping update"
                        _update_cmd=""
                    fi
                else
                    eval "$_update_cmd"
                fi
            else
                eval "$_update_cmd"
            fi
            if [[ -n "$_update_cmd" ]]; then
                print_success "Claude Code updated"
            fi
        else
            # get_claude_update_command returns 2 for "unknown" method
            print_warning "Could not determine how Claude Code was installed"
            print_info "Binary path: $_claude_bin"
            print_info "Please update manually using the method you originally used to install"
            print_warning "Skipping update"
        fi
    fi
else
    print_warning "Claude Code not installed"
    print_info "Claude Code is a CLI tool for agentic coding with Claude"
    print_info "Documentation: https://docs.claude.com/claude-code"
    echo ""

    if confirm "Install Claude Code?"; then
        _installed=false

        # Primary option: native installer (cross-platform)
        print_info "Option 1 (recommended): Native installer from claude.ai"
        if confirm "Install via native installer?"; then
            curl -fsSL https://claude.ai/install.sh | sh
            _installed=true
            print_success "Claude Code installed via native installer"
        fi

        # Secondary option: platform-specific package manager
        if [[ "$_installed" == "false" ]]; then
            if is_macos; then
                print_info "Option 2: Install via Homebrew"
                if confirm "Install via Homebrew?"; then
                    if ! command_exists brew; then
                        print_error "Homebrew not found. Please install Homebrew first:"
                        print_info "Visit: https://brew.sh"
                    else
                        # Add Anthropic tap if not already added
                        if ! brew tap | grep -q "anthropics/claude"; then
                            brew tap anthropics/claude
                        fi
                        brew install claude
                        _installed=true
                        print_success "Claude Code installed via Homebrew"
                    fi
                fi
            elif is_linux; then
                print_info "Option 2: Install via npm"
                if confirm "Install via npm?"; then
                    if ! command_exists npm; then
                        print_error "npm is required to install Claude Code"
                        print_info "Please install Node.js and npm first"
                    else
                        npm install -g @anthropic-ai/claude-code
                        _installed=true
                        print_success "Claude Code installed via npm"
                    fi
                fi
            fi
        fi

        if [[ "$_installed" == "false" ]]; then
            print_warning "Claude Code was not installed"
            print_info "You can install later with: curl -fsSL https://claude.ai/install.sh | sh"
        fi

        # Setup and authentication
        if [[ "$_installed" == "true" ]]; then
            echo ""
            print_info "Claude Code requires authentication"
            if confirm "Run 'claude auth' now to authenticate?"; then
                claude auth
            else
                print_warning "Remember to run 'claude auth' before using Claude Code"
            fi
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

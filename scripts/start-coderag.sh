#!/usr/bin/env bash

# =============================================================================
# CodeRAG MCP Wrapper Script
# =============================================================================
# Called by Claude Code MCP configuration to start CodeRAG server.
# Ensures Neo4j container is running before executing CodeRAG in STDIO mode.
#
# CRITICAL: All diagnostic output MUST go to stderr because stdout is used
# for MCP JSON-RPC communication between Claude Code and CodeRAG.
#
# Usage: Called automatically by MCP configuration (not for direct use)
# =============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
readonly COMPOSE_FILE="$DOTFILES_DIR/docker/coderag/docker-compose.yml"
readonly CODERAG_ENTRY="$DOTFILES_DIR/vendor/coderag/build/index.js"
readonly HEALTH_CHECK_TIMEOUT=30

# =============================================================================
# Helper Functions (all output to stderr)
# =============================================================================

log_info() {
    echo "[coderag] $*" >&2
}

log_error() {
    echo "[coderag] ERROR: $*" >&2
}

# =============================================================================
# Load Environment
# =============================================================================

load_environment() {
    local env_file="$DOTFILES_DIR/.env.mcp.local"

    if [[ -f "$env_file" ]]; then
        set -a
        # shellcheck source=/dev/null
        source "$env_file"
        set +a
    fi

    export CODERAG_NEO4J_PASSWORD
    export CODERAG_DATA_DIR="${CODERAG_DATA_DIR:-$HOME/neo4j-coderag}"
}

# =============================================================================
# Ensure Neo4j Container is Running
# =============================================================================

ensure_neo4j_running() {
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "docker-compose.yml not found at: $COMPOSE_FILE"
        exit 1
    fi

    log_info "Ensuring Neo4j container is running..."

    if ! docker compose -f "$COMPOSE_FILE" up -d >&2 2>&1; then
        log_error "Failed to start Neo4j container"
        exit 1
    fi
}

# =============================================================================
# Wait for Neo4j to be Healthy
# =============================================================================

wait_for_neo4j() {
    log_info "Waiting for Neo4j to be healthy (max ${HEALTH_CHECK_TIMEOUT}s)..."

    local i
    for i in $(seq 1 "$HEALTH_CHECK_TIMEOUT"); do
        if docker exec coderag-neo4j curl -sf http://localhost:7474 >/dev/null 2>&1; then
            log_info "Neo4j is healthy"
            return 0
        fi
        sleep 1
    done

    log_error "Neo4j failed to become healthy within ${HEALTH_CHECK_TIMEOUT}s"
    exit 1
}

# =============================================================================
# Verify CodeRAG Build Exists
# =============================================================================

verify_coderag_build() {
    if [[ ! -f "$CODERAG_ENTRY" ]]; then
        log_error "CodeRAG not built. Run: ./scripts/setup-coderag.sh"
        log_error "Expected: $CODERAG_ENTRY"
        exit 1
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    load_environment
    verify_coderag_build
    ensure_neo4j_running
    wait_for_neo4j

    log_info "Starting CodeRAG MCP server..."

    # Execute CodeRAG in STDIO mode
    # Using exec replaces this shell with node process
    # stdin/stdout pass through for MCP JSON-RPC communication
    exec node "$CODERAG_ENTRY"
}

main "$@"

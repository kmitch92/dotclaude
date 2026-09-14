#!/usr/bin/env bash

# =============================================================================
# Migrate a Machine to the Lean Config
# =============================================================================
# One-off switch-over, run after rewrite/lean-config is merged and stowed.
#   1. Checks the claude CLI is on PATH and ~/.claude/agents/worker.md exists.
#   2. Uninstalls the claude-mem@thedotmack plugin if `claude plugin list`
#      shows it.
#   3. Removes legacy user-scope MCP servers aws-core-mcp-server and
#      aws-cdk-mcp-server (failures ignored).
#   4. Runs <repo>/scripts/setup-mcp.sh (failure aborts the migration).
#   5. Moves legacy ~/.mcp.json (file or symlink, not followed) to
#      ~/.mcp.json.bak.<timestamp>.
#   6. Creates ~/.claude/machine.json {"workerCap": 2, "scoutCap": 6} if missing.
#   7. Runs `claude doctor` and reports auto-update status (warning only).
#
# Idempotent: a second run finds nothing to uninstall, no ~/.mcp.json to move
# and an existing machine.json (left untouched), and still succeeds.
#
# Usage: ./scripts/migrate-lean-config.sh [--dry-run]
#   --dry-run  print planned actions; only read-only claude calls
#              (plugin list, doctor); no files changed, setup-mcp.sh not run
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

readonly MEM_PLUGIN="claude-mem@thedotmack"
readonly LEGACY_MCP_SERVERS="aws-core-mcp-server aws-cdk-mcp-server"
readonly SETUP_MCP="$SCRIPT_DIR/setup-mcp.sh"
readonly LEGACY_MCP_JSON="$HOME/.mcp.json"
readonly MACHINE_JSON="$HOME/.claude/machine.json"
readonly WORKER_AGENT="$HOME/.claude/agents/worker.md"

usage() {
  echo "Usage: $(basename "$0") [--dry-run]"
  echo "  --dry-run  print planned actions without changing anything"
}

DRY_RUN=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      print_error "Unknown argument: $1"
      usage >&2
      exit 1
      ;;
  esac
done

check_prerequisites() {
  if ! command_exists claude; then
    print_error "claude CLI not found on PATH - install Claude Code first"
    exit 1
  fi
  if [ ! -f "$WORKER_AGENT" ]; then
    print_error "$WORKER_AGENT not found - merge rewrite/lean-config first (and stow it)"
    exit 1
  fi
}

uninstall_claude_mem() {
  local plugin_list
  if ! plugin_list="$(claude plugin list </dev/null 2>&1)"; then
    print_warning "claude plugin list failed - skipping $MEM_PLUGIN check"
    return 0
  fi
  if ! grep -Eq "(^|[[:space:]>])${MEM_PLUGIN}([[:space:]]|$)" <<< "$plugin_list"; then
    print_info "$MEM_PLUGIN not installed - nothing to uninstall"
    return 0
  fi
  if $DRY_RUN; then
    print_info "Would uninstall plugin: $MEM_PLUGIN"
    return 0
  fi
  if claude plugin uninstall "$MEM_PLUGIN" </dev/null >/dev/null 2>&1; then
    print_success "Uninstalled plugin: $MEM_PLUGIN"
  else
    print_error "Failed to uninstall plugin: $MEM_PLUGIN"
    exit 1
  fi
}

remove_legacy_mcp_servers() {
  local name
  for name in $LEGACY_MCP_SERVERS; do
    if $DRY_RUN; then
      print_info "Would remove user-scope MCP server: $name"
      continue
    fi
    if claude mcp remove --scope user "$name" </dev/null >/dev/null 2>&1; then
      print_success "Removed user-scope MCP server: $name"
    else
      print_info "User-scope MCP server $name not removed (likely absent)"
    fi
  done
}

run_setup_mcp() {
  if $DRY_RUN; then
    print_info "Would run: $SETUP_MCP"
    return 0
  fi
  if ! bash "$SETUP_MCP"; then
    print_error "setup-mcp.sh failed"
    exit 1
  fi
}

backup_legacy_mcp_json() {
  if [ ! -e "$LEGACY_MCP_JSON" ] && [ ! -L "$LEGACY_MCP_JSON" ]; then
    print_info "No $LEGACY_MCP_JSON - nothing to move"
    return 0
  fi
  local backup base_backup suffix
  base_backup="$LEGACY_MCP_JSON.bak.$(date +%Y%m%d%H%M%S)"
  backup="$base_backup"
  suffix=0
  while [ -e "$backup" ] || [ -L "$backup" ]; do
    suffix=$((suffix + 1))
    backup="$base_backup.$suffix"
  done
  if $DRY_RUN; then
    print_info "Would move $LEGACY_MCP_JSON -> $LEGACY_MCP_JSON.bak.<timestamp>"
    return 0
  fi
  # mv on the path itself renames a symlink without following it.
  mv -- "$LEGACY_MCP_JSON" "$backup"
  print_success "Moved $LEGACY_MCP_JSON -> $backup"
}

create_machine_json() {
  if [ -e "$MACHINE_JSON" ] || [ -L "$MACHINE_JSON" ]; then
    print_info "$MACHINE_JSON exists - leaving unchanged"
    return 0
  fi
  if $DRY_RUN; then
    print_info "Would create $MACHINE_JSON with workerCap 2, scoutCap 6"
    return 0
  fi
  printf '{"workerCap": 2, "scoutCap": 6}\n' > "$MACHINE_JSON"
  print_success "Created $MACHINE_JSON"
}

report_auto_updates() {
  local doctor_out auto_line
  doctor_out="$(claude doctor </dev/null 2>&1)" || print_warning "claude doctor exited non-zero"
  auto_line="$(awk 'tolower($0) ~ /auto-updates/ { print tolower($0); exit }' <<< "$doctor_out")"
  case "$auto_line" in
    *disabled*) print_success "auto-updates disabled" ;;
    *) print_warning "auto-updates still enabled - set DISABLE_AUTOUPDATER=1 to pin the CLI version" ;;
  esac
}

print_header "Migrate to Lean Config"

check_prerequisites

if $DRY_RUN; then
  print_warning "DRY RUN - no changes will be made"
fi

uninstall_claude_mem
remove_legacy_mcp_servers
run_setup_mcp
backup_legacy_mcp_json
create_machine_json
report_auto_updates

echo ""
if $DRY_RUN; then
  print_info "dry run complete - no changes made"
else
  print_success "migration complete"
fi

#!/usr/bin/env bash
# SubagentStop hook (scope "sub"): lints a subagent's last message the same
# way claude-ste-gate.sh does for the main Stop hook, but keys everything
# (the linter --session argument and the state-file name) off agent_id
# instead of session_id, since one top-level session can run many
# subagents concurrently.
#
# This script shares all logic with claude-ste-gate.sh by execing it with
# STE_SCOPE=sub set. See claude-ste-gate.sh for the full contract: env
# overrides (STE_LINT_BIN, STE_STATE_DIR, STE_LOG, STE_GATE), the
# one-retry property (stop_hook_active true => never block), the
# STE_GATE=warn switch to disable blocking, and the resilient handling of
# a missing/crashing linter or invalid stdin. Always exits 0.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STE_SCOPE=sub exec "$SELF_DIR/claude-ste-gate.sh"

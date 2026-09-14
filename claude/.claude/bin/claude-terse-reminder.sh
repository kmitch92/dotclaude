#!/usr/bin/env bash
# UserPromptSubmit hook: re-injects the terse-style reminder into context on every
# user prompt, to counter style-drift over long sessions.
#
# Claude Code treats UserPromptSubmit as one of the few events whose stdout is added
# to context. We emit the documented JSON `additionalContext` form so the reminder is
# wrapped in a system reminder and inserted alongside the submitted prompt.
#
# Contract: fast, deterministic, no external deps, always exit 0 (never block/error
# the prompt). Content is static, so a single-quoted heredoc literal is valid JSON
# with no escaping hazards.
set -euo pipefail

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"Style reminder: full rules in ~/.claude/output-styles/terse.md. One point per response, no essays. Stay on the current task; anything else is one \"Also:\" line. Plain technical words, nothing stylised. No claim without evidence. No praise, no apology. Prefer diagrams. Absolute paths."}}
JSON

exit 0

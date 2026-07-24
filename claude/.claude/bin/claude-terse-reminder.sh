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
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"Style reminder (terse mode): Address exactly one point per response — the single most important/actionable one — state it directly and stop. Drop articles and filler (just/really/basically), pleasantries and hedging; sentence fragments are fine. Any further points go as single-line bullets under \"Also:\" at the very end, never expanded inline. Write code, commit messages and PRs normally. No preamble, no recap, no waffle. ALWAYS write full absolute paths from / in output text — in prose, bullets, tables, AND inside directory diagrams — never bare filenames (index.ts), never relative paths (src/foo.ts), never leading-colon refs (:37). Line refs keep the absolute path: /abs/path/file.ts:37. This holds on every mention, including repeats."}}
JSON

exit 0

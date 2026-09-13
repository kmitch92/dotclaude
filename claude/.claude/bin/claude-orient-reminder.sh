#!/usr/bin/env bash
# PreToolUse hook (matcher: AskUserQuestion): injects an orientation reminder just
# before Claude asks the user a question, to counter questions that assume shared
# context the user does not have.
#
# The user runs several workstreams in parallel and context-switches constantly, so
# on returning to a chat window they have no recall of what Claude was mid-way
# through. This is the AskUserQuestion-shaped sibling of the UserPromptSubmit
# terse-style reminder: same mechanism, different event and target.
#
# Claude Code's PreToolUse hookSpecificOutput schema accepts an optional
# `additionalContext` alongside `permissionDecision`; when present it is emitted as a
# `hook_additional_context` attachment attributed to `PreToolUse:AskUserQuestion` and
# added to context. Omitting `permissionDecision` entirely leaves the permission flow
# untouched — this hook only adds context, it never allows, denies or asks.
#
# Contract: fast, deterministic, no external deps, always exit 0 (never block/error
# the tool call). Content is static, so a single-quoted heredoc literal is valid JSON
# with no escaping hazards.
set -euo pipefail

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"Orientation reminder (before this question reaches the user): they have NO context on what you are currently doing. They context-switch between parallel workstreams and right now have less working knowledge of this codebase than you do. Check the question you are about to ask. Does it open with one plain sentence saying what you are doing and why they are being interrupted? Is every domain term, symbol and filename defined inline, on the assumption they have never seen it? Are the options described by behaviour the user would observe, rather than by internal type or code shape? Could they answer without reading any code or recalling an earlier message? If any answer is no, rewrite the question before asking it. Absolute paths always. Orientation is one or two sentences — do not pad."}}
JSON

exit 0

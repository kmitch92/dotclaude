---
description: Restart this session in place — continue (not fork) the current Claude Code session in the same tmux pane, or relocate it to a new terminal window
allowed-tools: Bash(~/.claude/bin/claude-trestart.sh:*)
---

## Restart result

!`~/.claude/bin/claude-trestart.sh`

## Task

The restart script above has ALREADY executed — do not run it again.

- If the output starts with "RESTART OK": reply with one short sentence confirming the session is restarting in place, mentioning where (same tmux pane, or a new terminal window). Nothing else.
- If the output starts with "RESTART FAILED": relay the error to the user in one or two sentences, including the manual `claude --resume ...` command from the error if present.

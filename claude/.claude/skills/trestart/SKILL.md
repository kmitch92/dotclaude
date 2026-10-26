---
name: trestart
description: Continue this session in the same tmux pane, or move it to a new terminal window. Do not start a new one.
disable-model-invocation: true
allowed-tools: Bash(~/.claude/bin/claude-trestart.sh:*)
---

## Restart result

!`~/.claude/bin/claude-trestart.sh`

## Task

The script above ran, so do not run it again.

- If the output starts with `RESTART OK`, give one short sentence that states the session continues.
- Name the location, the same tmux pane or a new terminal window, and give no other text.
- If the output starts with `RESTART FAILED`, send the error to the user in one or two sentences, and include the manual `claude --resume ...` command when it does.

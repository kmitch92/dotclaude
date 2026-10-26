---
name: trestart
description: Continue this session in the same tmux pane, or move it to a new terminal window. Do not start a new one.
disable-model-invocation: true
allowed-tools: Bash(~/.claude/bin/claude-trestart.sh:*)
---

## Restart result

!`~/.claude/bin/claude-trestart.sh`

## Task

The script above ran. Do not run it again.

- If the output starts with `RESTART OK`:
  - Give one short sentence.
  - State that the session continues.
  - Name the location: the same tmux pane, or a new terminal window.
  - Give no other text.
- If the output starts with `RESTART FAILED`:
  - Send the error to the user in one or two sentences.
  - Include the manual `claude --resume ...` command when the error shows it.

---
description: Fork this session into an adjacent tmux pane (direction h/j/k/l, default right) or a new terminal window
argument-hint: [h|j|k|l]
allowed-tools: Bash(~/.claude/bin/claude-tfork.sh:*)
---

## Fork result

!`~/.claude/bin/claude-tfork.sh $ARGUMENTS`

## Task

The fork script above has ALREADY executed — do not run it again.

- If the output starts with "FORK OK": reply with one short sentence confirming the forked session is now open, mentioning where it was spawned (pane/window). Nothing else.
- If the output starts with "FORK FAILED": relay the error to the user in one or two sentences, including the manual `claude --resume ... --fork-session` command from the error if present.

---
name: tfork
description: Fork this session into a nearby tmux pane. Give a direction: one of h, j, k, or l. The default direction is right. You can also fork into a new terminal window.
disable-model-invocation: true
argument-hint: one of h, j, k, or l
allowed-tools: Bash(~/.claude/bin/claude-tfork.sh:*)
---

## Fork result

!`~/.claude/bin/claude-tfork.sh $ARGUMENTS`

## Task

The fork script above has ALREADY executed. Do not run it again.

- If the output starts with "FORK OK", give one short sentence.
- Say that the forked session is now open.
- Name where you started it (pane or window).
- Give nothing else.
- If the output starts with "FORK FAILED", give the error to the user in one or two sentences.
- If the error has the manual `claude --resume ... --fork-session` command, include it.

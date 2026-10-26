<!-- expect: none -->
<!-- note: the linter skips a frontmatter line, but it checks the description value. disable-model-invocation marks a line it must also skip. -->
---
name: example-skill
description: The skill runs a hook.
disable-model-invocation: true
allowed-tools: Read, Grep
---

The linter skips a frontmatter line.
It checks the description value for prose.

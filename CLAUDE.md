# dotclaude

This repo is the Claude Code configuration itself: rules, agents, hooks,
skills, settings and the install scripts that deploy them.

## Mechanism over instruction

If a behaviour can be enforced by a hook, a script or a settings key, build it
there. Prompt text is the last resort, for judgement that cannot be checked
mechanically.

A workflow that depends on an agent choosing to follow a rule, open a file or
read a doc fails silently and at random. A hook fires every time, reports what
it did, and can refuse.

```
settings.json    permissions, denies, model, effort, hook registration
hooks/           count, block, inject context at the moment of the action
scripts/         deploy, render templates, migrate — with tests
prompt text      only what none of the above can check
```

When a rule in a prompt keeps being missed, the fix is a mechanism, not
stronger wording.

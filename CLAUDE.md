# dotclaude

This repo holds the configuration for Claude Code: rules and agents, hooks
and skills, and settings, and the scripts that install them.

## Mechanism over instruction

When a hook, a script, or a settings key can make a behaviour occur on
its own, build it there. Prompt text is the last option. Use it only for
judgement no mechanism can check.

An agent can select a rule to follow, a file to open, or a doc to read —
or it can skip the step. A skipped step fails silently and at random. A
hook fires each time, reports what it did, and can refuse.

```
settings.json    permissions, denies, model, effort, hook registration
hooks/           count, block, inject context at the moment of the action
scripts/         deploy, render templates, migrate — with tests
prompt text      only what none of the above can check
```

When agents keep missing a rule stated only in a prompt, write a mechanism.
Do not restate the rule alone.

---
name: brief-writing
description: These are the full formats and rules for worker and scout task briefs. Read this before you write a brief too large for the short version in CLAUDE.md.
disable-model-invocation: true
---

## Principle

The primary session makes each decision, and the worker writes the code. A brief gives the behaviour, the signatures, the inputs, the outputs, and the edge conditions, and it also gives the test conditions to include. Do not write the code in the brief, and do not over-specify test assertions line by line.

If writing a brief puts a selection onto the worker, collect more information first, and do not send out a brief that is not fully specified.

## Size

One module has one test file, in each RED/GREEN pair, and a worker must stay in its 60-turn limit. Divide larger work into more modules, instead of writing one large brief.

Keep each module in its own files, with no shared edits, and let them run in parallel. Many briefs that are small and atomic go faster than a few large ones.

## Worker brief format

Use the same words as shown in this block:

```
ROLE        RED | GREEN | REFACTOR | CHORE
SKILLS      absolute paths of skill files to read first (may be empty)
FILES       absolute paths, each marked edit | read-only | do-not-edit
TARGET      symbols or modules to change
SPEC        behaviour: signatures, inputs, outputs, edge cases
ACCEPTANCE  each check: command + expected result
BAIL        task-specific stop conditions
REPORT      status done|bailed · files changed · result line per check · bail reason
```

Field notes:

- Give absolute paths for SKILLS, for example `/home/<user>/.claude/skills/typescript/SKILL.md`, expanding `~` to the actual home path, and write only the skills necessary for the task.
- Give absolute paths for FILES, each marked `edit`, `read-only`, or `do-not-edit`, and mark test files `do-not-edit` in REFACTOR briefs and GREEN briefs.
- Give each check as a command plus its expected result, for ACCEPTANCE, and write that the tests must fail, with the cause of that failure, for a RED brief.
- Write that the checks must succeed, for a REFACTOR brief or a GREEN brief, and use only the test file of the module, never the full suite.
- Give task-specific conditions only, for BAIL, and keep the default bail conditions in the worker agent file, instead of writing them here again.
- Give the fixed fields from the block above, for REPORT, at all times, and do not add or remove fields.

## Scout brief format

Use the same words as shown in this block:

```
QUESTION    what to find
SCOPE       optional: paths or globs to start from
RETURN      output format, e.g. /abs/path:line — fact
```

Scout briefs are loose on purpose, since the scout finds what you do not know.

Open questions are good, for example "where is auth checked?", "what calls `saveOrder`?", or "map `src/billing/`: entry points, tests, conventions".

- Write one question for each scout, and make sure RETURN has the shape `/abs/path:line — fact`.
- SCOPE is a starting hint, so do not write it when you do not know where to look.
- When the area is unknown, send one or more map scouts first.
- Give them a brief like "list the modules below X and what each does".
- Send targeted scouts out from what they found, and send many narrow scouts in parallel, instead of one wide scout.

## Model

Keep the model selection in the agent files (`worker.md`, `scout.md`) unless the plan explicitly overrides it.
</content>

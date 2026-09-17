---
name: brief-writing
description: Full formats and rules for worker and scout task briefs. Read before writing a brief that needs more than the short form in CLAUDE.md.
disable-model-invocation: true
---

## Principle

The main session makes every decision; the worker writes the code. A brief specifies behaviour, signatures, inputs, outputs, edge cases, and the test cases to cover. Do not write the code in the brief. Do not over-specify test assertions line by line.

If a brief cannot be written without leaving a choice to the worker, gather more information first. Do not dispatch an underspecified brief.

## Size

One module — one test file — per RED/GREEN pair. A worker should finish well inside its 60-turn cap. Split larger work into more modules rather than writing a bigger brief.

Design modules to be independent — separate files, no shared edits — so they can run in parallel. Many small atomic briefs finish faster than a few large ones.

## Worker brief format

Copy this block exactly:

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

- **SKILLS**: absolute paths, e.g. `/home/<user>/.claude/skills/typescript/SKILL.md` — expand `~` to the real home path. List only skills the task needs.
- **FILES**: absolute paths, each marked `edit`, `read-only`, or `do-not-edit`. GREEN and REFACTOR briefs mark test files `do-not-edit`.
- **ACCEPTANCE**: each check is a command plus its expected result. RED briefs expect the tests to fail, and state the reason they must fail. GREEN and REFACTOR briefs expect the checks to pass. Target only the module's own test file — never the full suite.
- **BAIL**: task-specific conditions only. The worker agent file already carries the default bail conditions; do not repeat them here.
- **REPORT**: always the fixed fields from the block above. Do not add or remove fields.

## Scout brief format

Copy this block exactly:

```
QUESTION    what to find
SCOPE       optional: paths or globs to start from
RETURN      output format, e.g. /abs/path:line — fact
```

Scout briefs are loose on purpose: the scout finds what you don't know yet. Open questions are fine ("where is auth checked?", "what calls `saveOrder`?", "map `src/billing/`: entry points, tests, conventions").

- One question per scout. RETURN must ask for `/abs/path:line — fact` form.
- SCOPE is a starting hint. Omit it when you don't know where to look.
- When the area is unknown, send one or more map scouts first ("list the modules under X and what each does"), then fan out targeted scouts from their findings.
- Prefer many narrow scouts in parallel over one wide scout.

## Model

Leave the model choice to the agent files (`worker.md`, `scout.md`) unless the plan explicitly overrides it.

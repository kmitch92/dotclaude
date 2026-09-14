Rules apply to every agent — main session and subagents. Rules under "When writing to the user" apply only to text shown to the user; subagents follow the report format in their brief instead. "Delegation" applies only to the main session.

## When writing to the user

- Open with one plain sentence: what you are doing, why you are interrupting. Define every term, symbol, file on first use in that message. Describe options by behaviour the user would see, not code shape. The user must not need to read code or recall an earlier message to answer.
- One point per response. Other points: one line each under "Also:" at the end.
- Plain technical words. Nothing stylised. No praise. No apology.
- Prefer ASCII diagrams (box-drawing, under 100 columns, no mermaid) for flows and structure.
- Absolute file paths, always.

## Evidence

- No claim without evidence. Name the files you read.
- Keep separate: what you read, what you ran, what you infer.
- If you don't know, say so. Never present a later check as your earlier reasoning.
- The user's account of their own system outranks your search; find the layer you missed.
- A question you raised stays open until answered; carry the caveat.

## Delegation (main session only)

Workers and scouts skip this section.

- Delegate by default. Work directly only for small edits to known files, questions, and config. Read at most a few files yourself.
- The only subagents are `scout` and `worker`. No other types.
- Lookups go to scouts: one open question each, starting paths optional. Unknown area: map scouts first, then targeted scouts from their findings. Launch every free slot up to `scoutCap` (`~/.claude/machine.json`) in one message.
- New code with tests, or reading more than a few files first: load the `orchestrate` skill before exploring, not after. It runs workers in parallel up to `workerCap`.
- The user can override either way.

## Tests

Write the failing test first for code with logic. Run only the test files for the change; never the full suite unless asked.

## Git

Never push. Never amend, rebase, reset --hard, or force-push. Commit only when the user asks, except commits made by the orchestrate skill.

## When blocked

Stop, report, wait.

## Docs

Never create new .md files without user approval, except orchestrate plan files in `.plans/`.

## Ask vs proceed

Ask when requirements are unclear, several approaches have different trade-offs, or a change breaks existing behaviour. Otherwise proceed.

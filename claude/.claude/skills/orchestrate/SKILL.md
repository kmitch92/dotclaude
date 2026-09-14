---
name: orchestrate
description: Plan and run work that splits into several tasks. Writes a plan, dispatches scout and worker subagents with task briefs, reviews results, commits per stage.
effort: xhigh
---

## Terms

- **plan** — the plan file.
- **phase** — a group of modules.
- **module** — one unit of work, sized to one test file.
- **stage** — RED, GREEN, REFACTOR, or CHORE.
- **brief** — the brief given to a worker or scout.
- **bail** — a worker stops and reports instead of finishing.
- **checkpoint** — a point where the plan pauses for approval.
- **re-brief** — a corrected brief sent after a bail.

## 1. Setup

Read `~/.claude/machine.json` for `workerCap` and `scoutCap`, default 2 and 6 if missing. A hook also enforces the caps; if blocked, wait for running agents to finish, then retry.

## 2. Retrieve

Gather information with scouts, in parallel up to `scoutCap`. Read code yourself only where needed. Before writing any brief, read `~/.claude/skills/brief-writing/SKILL.md`.

## 3. Plan

Write the plan file to `<project root>/.plans/<plan-name>.md`, format in `~/.claude/skills/orchestrate/plan-format.md`. Create `.plans/` if missing; add it to the project `.gitignore`, creating that file too if needed. The plan sets: phases, modules, stages, checkpoints, re-brief limit (default 1), unattended yes/no.

## 4. Approval

Show the user a short plan summary and wait for approval before any worker runs. Scouts may run first — they are read-only. Skip the wait only if the user asked to run unattended.

## 5. Run each phase

Per module: send a RED brief to a worker, review its report and diff, commit `test(<scope>): ...`; then a GREEN brief to a separate worker, review, commit `feat(<scope>): ...` or `fix(<scope>): ...`. RED and GREEN are always separate runs. Modules in a phase run in parallel up to `workerCap`. Non-logic work uses CHORE briefs, committed `chore` or `docs`.

## 6. Bails

Read the bail reason and fix the cause — possibly your own brief. Fix a wrong test only with a new RED brief; GREEN workers and the orchestrator never edit tests. Hitting `maxTurns` with partial output also counts as a bail. Re-brief up to the plan's limit, then stop that module, continue independent modules, and report it at the next checkpoint or end.

## 7. End of phase

Review the phase diff yourself. If changes are needed, send REFACTOR briefs to workers and commit `refactor(<scope>): ...`. Stop at the checkpoint after this phase, if the plan has one.

## 8. After every stage

Update the plan file: status, commit hash, and a log line.

## 9. Commits

Local only, with conventional commit messages. Stage explicit paths — never `git add -A` or `git add .`. Never push, amend, rebase, or `reset --hard`.

## 10. Resume

If a plan file for this work has incomplete stages, follow `~/.claude/skills/orchestrate/resume.md`.

## 11. End

Report: status per module, commit hashes, and bailed modules with reasons.

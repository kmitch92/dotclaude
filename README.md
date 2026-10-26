# dotclaude

dotclaude is a personal configuration for Claude Code (the command-line
agent). It sets lean rules. Output stays terse and strict, in the style of
ASD-STE100 (Simplified Technical English). It also runs its own system for
orchestration.

## Layout

```
.
├── install.sh              deps, backup, stow, MCP deploy
├── bin/
│   └── claude-bare          launcher, isolated config dir
├── scripts/
│   ├── setup-mcp.sh          renders template, registers via claude CLI
│   ├── setup-machine.sh      writes machine.json from template
│   ├── migrate-lean-config.sh  one-off switch of an old machine
│   ├── install-claude-code.sh
│   ├── list-mcp-tools.sh
│   ├── clean-ephemeral.sh
│   ├── utils.sh
│   └── tests/                 shell tests
├── mcp/
│   └── mcp.json.template      4 MCP servers
└── claude/.claude/            stowed to ~/.claude
    ├── CLAUDE.md               rules, every agent
    ├── machine.template.json   default agent caps, copied to machine.json
    ├── settings.json           model, hooks, output style, permissions
    ├── agents/                 worker.md, scout.md
    ├── skills/                 stack skills + user commands
    ├── hooks/                  agent-cap, worker-git-block, track-session, cowork-notice, pre-compact, session-start-compact, compact-timeline
    ├── bin/                    reminder hooks, STE linter and gates, report, tfork, trestart
    ├── ste/                    STE rules.tsv, phrases.tsv, tests/
    ├── output-styles/          terse.md
    ├── lessons/                grok output
    └── scripts/                notify-claude.sh
```

## How it works

```
main session — plans, delegates, reviews, consolidates
       |
       +--> scout   (read-only lookup, Haiku, one question each)
       +--> worker  (one brief, one change, Haiku, RED then GREEN)
       |            agent-cap hook refuses launches past the caps
       v
  reviews each report and diff
       |
       v
  user checks the diff in lazygit, runs /commit
```

## Voice: five layers

1. Output style (`output-styles/terse.md`): sets the shape of a reply,
   plus STE grammar and vocabulary.
2. Global rules (`CLAUDE.md`): set honesty, the `Evidence` rules, and one
   clear name for each term.
3. Per-prompt reinforcement with measurement
   (`bin/claude-terse-reminder.sh`) puts the style reminder and the set of
   checks from `ste/rules.tsv` into the prompt. It also puts in the lint
   result of the previous reply. It reads that result from the state
   file the Stop gate wrote, with a transcript as a fallback.
4. Stop gate (`bin/claude-ste-gate.sh`): runs `bin/claude-ste-lint.py` on
   the last reply, writes the state file the next prompt reads, and adds
   to the log. It prints nothing and never refuses a reply, because
   writing a second full reply has a cost.
5. Subagent voice by schema (`agents/worker.md`, `agents/scout.md`):
   gives the report fields. The linter checks the free-text fields at
   SubagentStop with `bin/claude-ste-subagent-gate.sh`.

```
 reply --> Stop gate --> linter --> state file + log --> next prompt
                                                           reminder
```

- `bin/claude-orient-reminder.sh` — reminder before each question to the
  user.

## Voice linter

### Checks

IDs, classes, and corrections for each check live in `ste/rules.tsv`.
All 13 checks carry class `warn`, and the gate never refuses a reply for
a hit on any check. The next prompt shows the result of the last reply.

Length and shape: SENTENCE-LENGTH flags a sentence past 25 words,
PARAGRAPH-LENGTH flags a main-scope paragraph past six sentences, and
PROSE-WORDS flags a response that runs over its word budget. ALSO-COUNT
flags more than three "Also:" lines, and ALSO-LENGTH flags an "Also:"
line past 20 words.

Typography and grammar: CONTRACTION flags a contraction in place of the
words in full, and SEMICOLON flags a semicolon outside a code block.
LATIN flags a Latin abbreviation in place of a plain phrase such as "for
example" or "that is". PASSIVE-BY flags passive voice that names the
actor with "by". THIS-PRONOUN flags a sentence that opens with "This",
"It", or "That" plus a verb, leaving the noun unnamed.

Register: NARRATION flags an intent statement in place of a finding,
FILLER-OPEN flags an opener such as "Great" or "Absolutely", and SLOP
flags an empty intensifier or a vague hedge. Each of these three checks
draws its phrase list from `ste/phrases.tsv`.

The repo dropped its vocabulary check for a measured reason. Run against
8133 words of this repo's own prose, the old dictionary check produced
807 hits across 246 distinct words. The words it fired on most were
ordinary technical English, among them pass, list, order, every, and
under. Programming needs far more nouns and verbs than an aerospace
dictionary holds.

### Report

Run `bin/claude-ste-report.sh [--days N]`. Each metric reports one fact:

- lints: the total count of lint runs.
- hit rate: the share of replies that broke a check.
- gate errors: the number of times the linter itself failed to run.
- top ids: the rule IDs that fire most often.
- prose words: the minimum, median, and maximum word count of main-scope
  replies.

### Not enforced

Some STE rules stay prompt-only. No automated check runs for rule 1.3
(word meaning), rule 1.11 (synonym substitution), rule 3.7
(nominalisation), or rule 4.5 (`articles`). The word selection for
`Evidence` (`read`, `ran`, `infer`) and define-on-first-use also stay
prompt-only.

One local deviation also applies. The words `I`, `me`, and `my` stay
permitted. American spelling stays unenforced, with no vocabulary check
in place to flag it.

### Tests

Run `bash ~/.claude/ste/tests/run.sh`. It checks the lint fixtures, the
transcript fallback, the state replay, the latency (below 150 ms), and
resilience.

Run the hook tests in `bin/`: `claude-ste-gate.test.sh`,
`claude-ste-subagent-gate.test.sh`, `claude-terse-reminder.test.sh`, and
`claude-ste-report.test.sh`.

## Skills

A person types each skill by hand (`/name`). No skill starts on its own.

- Stack skills, read by workers when a brief names them: `aws-diagnostics`,
  `backend`, `docs`, `react`, `security-performance`, `shell`, `testing`,
  `typescript`. `brief-writing` holds the full brief formats, for when the
  short version in `CLAUDE.md` is not sufficient.
- User commands: `commit`, `cruft`, `docs-drift`, `domain-modeling`, `grill`,
  `grill-with-docs`, `grok`, `merge`, `review-pr`, `tfork`, `trestart`,
  `typetest`, `writing-great-skills`.

## Hooks

- `agent-cap` — stops worker and scout launches above the per-machine limit.
- `worker-git-block` — blocks git commit, push, rebase, reset --hard in workers.
- `track-session` — records session id and cwd for `tfork`/`trestart`.
- `cowork-notice` — tells you when a different session shares the branch and cwd.
- `ste-gate` — lints the last reply at Stop, writes the state file, and
  adds to the log. It never refuses a reply.
- `ste-subagent-gate` — lints a worker or scout report at SubagentStop, checking only the free-text fields.

## Per-machine config

`.gitignore` excludes `claude/.claude/machine.json`. `install.sh` (or
`scripts/setup-machine.sh`) writes it from the tracked template
`claude/.claude/machine.template.json`:

```json
{"workerCap": 5, "scoutCap": 10}
```

Each run replaces `machine.json`. To change the limits, edit the template
and rerun `scripts/setup-machine.sh`. The agent-cap hook defaults to 2/6 if
`machine.json` is not there.

## Install

GNU Stow, gettext (`envsubst`), and `jq` are necessary. Node.js/npm and `uv`
are optional, for the Claude Code CLI and MCP servers.

```
./install.sh
```

Backs up `~/.claude` and `~/.mcp.json`, stows `claude/.claude/` to
`~/.claude`, installs the CLI, writes `~/.claude/machine.json` from the
template, and adds the MCP servers.

`scripts/setup-mcp.sh` renders `mcp/mcp.json.template` with `envsubst` and
adds each server with `claude mcp add-json --scope user`. Set
`CONTEXT7_API_KEY` in `.env.mcp.local` (empty skips `context7`).

## Migrate an old machine

```
./scripts/migrate-lean-config.sh --dry-run
./scripts/migrate-lean-config.sh
```

Uninstalls the claude-mem plugin, removes legacy AWS MCP servers, runs
`setup-mcp.sh`, moves `~/.mcp.json` to a `.bak` file, makes `machine.json`
from the template through `setup-machine.sh`. Safe to rerun.

## Updates

Models pinned in `settings.json`, `worker.md`, `scout.md`. Claude Code runs
the stable release. Auto-update stays off. Run `claude update` by hand.

## Tests

Run one file at a time with `bash <file>`: `scripts/tests/*.test.sh`,
`claude/.claude/hooks/*.test.sh`, `claude/.claude/bin/*.test.sh`.

## Uninstall

```
stow -D claude
```

Removes the `~/.claude` symlink. MCP servers stay registered. Remove each
one with `claude mcp remove --scope user <name>`.

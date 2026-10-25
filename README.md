# dotclaude

Personal Claude Code config: lean core rules, strict terse output in
ASD-STE100, own orchestration system.

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
    ├── ste/                    STE rules.tsv, glossary.txt, banned.txt, british.tsv, extract-dict.py, tests/; dict/ is gitignored
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
2. Global rules (`CLAUDE.md`): set honesty, the Evidence rules, and the
   glossary rule.
3. Per-prompt reinforcement with measurement
   (`bin/claude-terse-reminder.sh`): injects the style reminder and the
   block-class STE check list from `ste/rules.tsv`. It also injects the lint
   result of the previous reply, read from the state file the Stop gate
   wrote, with a transcript fallback.
4. Stop gate (`bin/claude-ste-gate.sh`): runs `bin/claude-ste-lint.py` on
   the final reply. A block-class hit refuses the reply once, and the
   retry never gets refused. `env.STE_GATE = "warn"` in `settings.json`
   keeps the gate in report-only mode for rollout phase 1. Remove the key
   to enforce the gate.
5. Subagent voice by schema (`agents/worker.md`, `agents/scout.md`):
   defines the report fields. The linter checks the free-text fields at
   SubagentStop with `bin/claude-ste-subagent-gate.sh`.

```
 reply --> Stop gate --> linter --> state file + log --> next prompt
                                                           reminder
```

- `bin/claude-orient-reminder.sh` — reminder before each question to the
  user.

## STE linter

### Dictionary

The source PDF holds the STE dictionary and is copyrighted. The install
never commits it. `ste/dict/` is listed in `.gitignore`. Regenerate the
dictionary with these two commands:

```
pdftotext -layout ~/Downloads/asd-ste100-issue-9.pdf ~/.claude/ste/dict/ste9.txt
python3 ~/.claude/ste/extract-dict.py ~/.claude/ste/dict/ste9.txt
```

Expected counts: 846 approved words, 1313 unapproved words (1232 with an
alternative), 196 verb-form rows, 39 recurring errors.

### Checks

IDs, classes and fixes for each STE check live in `ste/rules.tsv`. A
block class refuses a reply. A warn class gets reported on the next
prompt.

Block: SENTENCE-LENGTH, CONTRACTION, COMPLEX-VERB, USING, PASSIVE-BY,
UNAPPROVED, BANNED, SEMICOLON, LATIN.

Warn: PASSIVE, ING-FORM, NOUN-CLUSTER, ONE-INSTRUCTION, IMPERATIVE,
PARAGRAPH-LENGTH, THIS-PRONOUN, POSSESSIVE, SAFETY, UNKNOWN, POS,
PROSE-WORDS, ALSO-COUNT, ALSO-LENGTH.

### Glossary

The glossary admits a word only if it names a specific software thing (a
noun) or a specific software operation (a verb). Adjectives and adverbs
never qualify. `banned.txt` holds register words that the dictionary does
not map. The glossary wins when a word appears in both lists.

### Report

Run `bin/claude-ste-report.sh [--days N]`. Each metric reports one fact:

- lints: the total number of lint events.
- block rate: the share of replies the gate would refuse.
- retry rate: the share of refused replies that a later reply fixed.
- gate errors: the number of times the linter itself failed to run.
- top ids: the rule IDs that fire most often.
- top unapproved: the unapproved words that fire most often, each with a
  fix.
- top unknown: the words the linter does not recognise at all. This list
  feeds the glossary.
- prose words: the minimum, median and maximum word count of main-scope
  replies.

### Not enforced

Some STE rules stay prompt-only, with no automated check: rule 1.3 (word
meaning), rule 1.11 (synonym drift), rule 3.7 (nominalisation), rule 4.5
(articles), the Evidence register (`read`, `ran`, `infer`), and
define-on-first-use.

One local deviation also applies. The words `I`, `me` and `my` stay
permitted. American spelling stays unenforced, and `british.tsv`
normalises a British word for dictionary lookup.

### Tests

Run `bash ~/.claude/ste/tests/run.sh` for the extractor fixture, the lint
fixtures, the transcript fallback, the state replay, the latency check
(under 150 ms), and the resilience check.

Run the hook tests in `bin/`: `claude-ste-gate.test.sh`,
`claude-ste-subagent-gate.test.sh`, `claude-terse-reminder.test.sh`, and
`claude-ste-report.test.sh`.

## Skills

Every skill is typed by hand (`/name`); none start themselves.

- Stack skills, read by workers when a brief lists them: `aws-diagnostics`,
  `backend`, `docs`, `react`, `security-performance`, `shell`, `testing`,
  `typescript`. `brief-writing` holds the full brief formats, for when the
  short form in `CLAUDE.md` is not enough.
- User commands: `commit`, `cruft`, `docs-drift`, `domain-modeling`, `grill`,
  `grill-with-docs`, `grok`, `merge`, `review-pr`, `tfork`, `trestart`,
  `typetest`, `writing-great-skills`.

## Hooks

- `agent-cap` — enforces per-machine parallel caps on worker/scout subagents.
- `worker-git-block` — blocks git commit, push, rebase, reset --hard in workers.
- `track-session` — records session id and cwd for `tfork`/`trestart`.
- `cowork-notice` — warns when another session shares cwd and branch.
- `ste-gate` — lints the final reply at Stop. A block-class hit refuses
  the reply once, and the retry never gets refused.
- `ste-subagent-gate` — lints a worker or scout report at SubagentStop,
  checking only the free-text fields.

## Per-machine config

`claude/.claude/machine.json` is gitignored, written from the tracked
template `claude/.claude/machine.template.json` by `install.sh` (or
`scripts/setup-machine.sh`):

```json
{"workerCap": 5, "scoutCap": 10}
```

Each run replaces `machine.json`. To change caps, edit the template and rerun
`scripts/setup-machine.sh`. The agent-cap hook defaults to 2/6 if
`machine.json` is missing.

## Install

Needs GNU Stow, gettext (`envsubst`), and `jq`. Recommended: Node.js/npm and `uv`
for the Claude Code CLI and MCP servers.

```
./install.sh
```

Backs up `~/.claude` and `~/.mcp.json`, stows `claude/.claude/` to
`~/.claude`, installs the CLI, writes `~/.claude/machine.json` from the
template, registers MCP servers.

`scripts/setup-mcp.sh` renders `mcp/mcp.json.template` with `envsubst` and
registers each server with `claude mcp add-json --scope user`. Set
`CONTEXT7_API_KEY` in `.env.mcp.local` (empty skips `context7`).

## Migrate an old machine

```
./scripts/migrate-lean-config.sh --dry-run
./scripts/migrate-lean-config.sh
```

Uninstalls the claude-mem plugin, removes legacy AWS MCP servers, runs
`setup-mcp.sh`, moves `~/.mcp.json` to a `.bak` file, creates `machine.json`
from the template via `setup-machine.sh`. Safe to rerun.

## Updates

Models pinned in `settings.json`, `worker.md`, `scout.md`. Claude Code on the
stable channel, auto-update off; run `claude update` by hand.

## Tests

Run one file at a time with `bash <file>`: `scripts/tests/*.test.sh`,
`claude/.claude/hooks/*.test.sh`, `claude/.claude/bin/*.test.sh`.

## Uninstall

```
stow -D claude
```

Removes the `~/.claude` symlink. MCP servers stay registered; remove each with
`claude mcp remove --scope user <name>`.

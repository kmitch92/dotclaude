# dotclaude

Personal Claude Code config: lean core rules, strict terse output, own
orchestration system.

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
    ├── skills/                 orchestrate + stack skills + commands
    ├── hooks/                  agent-cap, worker-git-block, track-session, cowork-notice
    ├── bin/                    reminder hooks, tfork, trestart
    ├── output-styles/          terse.md
    ├── lessons/                grok output
    └── scripts/                notify-claude.sh
```

## How it works

```
main session (small edits: works directly)
       |
       | needs tests or exploration
       v
  orchestrate skill
       |
       v
  writes plan -> <project>/.plans/<name>.md
       |
       +--> scout   (read-only, Haiku, up to scoutCap)
       +--> worker  (one brief, Haiku, up to workerCap)
       |
       v
  reviews report + diff
       |
       v
  commits per stage (RED / GREEN / REFACTOR / CHORE)
```

## Rules and output

- `CLAUDE.md` — core rules, max 500 words, loaded by every agent.
- `output-styles/terse.md` — main session only.
- `bin/claude-terse-reminder.sh` — style reminder on every prompt.
- `bin/claude-orient-reminder.sh` — reminder before each question to the user.

## Skills

`orchestrate` is the only skill Claude starts itself. Everything else is
typed only (`/name`).

- Stack skills, read by workers when a brief lists them: `aws-diagnostics`,
  `backend`, `docs`, `react`, `security-performance`, `shell`, `testing`,
  `typescript`. `brief-writing` is for `orchestrate` only.
- User commands: `commit`, `cruft`, `docs-drift`, `domain-modeling`, `grill`,
  `grill-with-docs`, `grok`, `merge`, `review-pr`, `tfork`, `trestart`,
  `typetest`, `writing-great-skills`.

## Hooks

- `agent-cap` — enforces per-machine parallel caps on worker/scout subagents.
- `worker-git-block` — blocks git commit, push, rebase, reset --hard in workers.
- `track-session` — records session id and cwd for `tfork`/`trestart`.
- `cowork-notice` — warns when another session shares cwd and branch.

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

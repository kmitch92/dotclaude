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
│   ├── install-claude-code.sh
│   ├── list-mcp-tools.sh
│   ├── clean-ephemeral.sh
│   ├── utils.sh
│   └── tests/                 shell tests
├── mcp/
│   └── mcp.json.template      4 MCP servers
└── claude/.claude/            stowed to ~/.claude
    ├── CLAUDE.md               rules, every agent
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
main session (default: works directly)
       |
       | work splits into several tasks
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

- `claude/.claude/CLAUDE.md` — core rules, at most 500 words, loaded by every
  agent.
- Output style Terse (`claude/.claude/output-styles/terse.md`) — main session
  only.
- Per-prompt reminder hook — `claude/.claude/bin/claude-terse-reminder.sh`.
- Pre-question orientation hook — `claude/.claude/bin/claude-orient-reminder.sh`.

## Skills

`orchestrate` is the only skill Claude starts itself. Everything else is
typed only (`/name`).

- Stack skills, read by workers when a brief lists them: `aws-diagnostics`,
  `backend`, `docs`, `react`, `security-performance`, `shell`, `testing`,
  `typescript`. `brief-writing` is read by `orchestrate` itself, not workers.
- User commands: `commit`, `cruft`, `docs-drift`, `domain-modeling`, `grill`,
  `grill-with-docs`, `grok`, `merge`, `review-pr`, `tfork`, `trestart`,
  `typetest`, `writing-great-skills`.

## Hooks

- `agent-cap` — enforces per-machine parallel caps on worker/scout subagents.
- `worker-git-block` — blocks git commit/push inside worker subagents.
- `track-session` — records session id and cwd for `tfork`/`trestart`.
- `cowork-notice` — warns when another session shares cwd and branch.
- reminders — `claude-terse-reminder.sh`, `claude-orient-reminder.sh`.

## Per-machine config

`claude/.claude/machine.json` (gitignored), defaults 2/6 when missing:

```json
{"workerCap": 2, "scoutCap": 6}
```

## Install

Prerequisites (checked by `install.sh`): GNU Stow and gettext (`envsubst`),
required; Node.js/npm and `uv` (`uvx`), recommended, for the Claude Code CLI
and MCP servers.

```
./install.sh
```

Backs up any existing `~/.claude` and `~/.mcp.json`, symlinks
`claude/.claude/` to `~/.claude` with `stow`, installs the Claude Code CLI,
deploys MCP config.

`scripts/setup-mcp.sh` renders `mcp/mcp.json.template` with `envsubst`, runs
`claude mcp remove --scope user <name>`, `claude mcp add-json --scope
user <name> <json>` per server. Requires `claude` CLI; never writes
`~/.mcp.json`. No `.env.mcp` file exists — create `.env.mcp.local` and set
`CONTEXT7_API_KEY` (empty skips `context7`).

## Updates

Models are pinned: `settings.json` sets the main session model;
`claude/.claude/agents/worker.md` and `scout.md` pin their own. Claude Code
stays on the stable channel, auto-update off (`autoUpdatesChannel: stable`,
`DISABLE_AUTOUPDATER=1`) — run `claude update` deliberately.

## Tests

Shell tests, run individually with `bash <file>`:

- `scripts/tests/*.test.sh` — install/setup scripts.
- `claude/.claude/hooks/*.test.sh` — hooks.
- `claude/.claude/bin/*.test.sh` — `tfork`, `trestart`.

## Uninstall

```
stow -D claude
```

Removes the `~/.claude` symlink.

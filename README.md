# ✨ dotclaude

> **A standalone, production-ready Claude Code configuration system with specialized AI agents, comprehensive documentation, and automated MCP server setup.**

---

## 📖 Overview

**dotclaude** is a complete Claude Code configuration repository that implements a sophisticated multi-agent development system. It provides:

- **12 Specialized AI Agents**: Each agent is an expert in a specific domain (testing, architecture, security, etc.)
- **Test-Driven Development Framework**: Non-negotiable TDD with Red-Green-Refactor cycle
- **Project CLAUDE.md as Primary Documentation**: Single source of orchestration rules, standards, and workflows for all agents
- **MCP Server Integration**: 7 pre-configured Model Context Protocol servers for enhanced capabilities
- **Automated Installation**: One-command setup with intelligent dependency handling
- **Symlink-Based Architecture**: Uses GNU stow for clean, version-controlled configuration management

This repository can be used **independently** or alongside your existing dotfiles. It doesn't require or depend on any other configuration system.

### Key Features

- 🤖 **Agent Orchestration**: Main Agent delegates to specialists, never implements directly
- 🧪 **TDD Enforcement**: Every line of production code requires a failing test first
- 🔒 **Security & Performance**: Dedicated agent for OWASP compliance and optimization
- 📚 **Schema-First Development**: Zod schemas first, types derived from them
- 🔄 **Immutable Patterns**: Pure functions, no data mutation, functional paradigm
- 🚀 **Production-Ready**: Pre-commit checklists, quality gates, deployment workflows

---

## 📦 What's Included

### Specialized Agents (12)

| Agent | Domain | Purpose |
|-------|--------|---------|
| **Technical Architect** | Planning & Design | Task breakdown, feature planning, WIP management |
| **Test Writer** | Testing & TDD | Behavioral tests, coverage verification, TDD cycle |
| **TypeScript Connoisseur** | Type Systems | Advanced TypeScript, Zod schemas, strict mode |
| **Quality & Refactoring Specialist** | Code Review | Quality assessment, refactoring guidance, tier-based standards |
| **Production Readiness Specialist** | Security & Performance | Security audits, performance optimization, deployment readiness |
| **Backend TypeScript Specialist** | Backend Development | Contract-first API/database design, REST/GraphQL, Lambda, DynamoDB |
| **Git Specialist** | Version Control | Commits, branches, history — never pushes or opens PRs |
| **Shell Specialist** | Automation | Shell scripting, system automation, git hook implementation, CI/CD scripts |
| **React Engineer** | Frontend Development | React 19+, Next.js, Remix, hooks, SSR |
| **Documentation Specialist** | Documentation | Project docs, ADRs, quality audits, learning capture |
| **Task Explorer** | Codebase Onboarding | Read-only context reports for new tickets or unfamiliar code |
| **Subtask List Generator** | Bulk Fixes | Exhaustive pattern search, standardisation checklists |

### Skills (8)

Skills are auto-discovered from `claude/.claude/skills/`. **Model-invoked** skills are picked up automatically by Claude based on their description; **user-invoked** skills are launched by typing their name by hand and never trigger automatically.

| Skill | Invocation | Purpose |
|-------|------------|---------|
| **docs-drift** | User-invoked (`docs-drift`) | Walk every tracked markdown file, diff it against the commits since its last edit, and repair what's gone stale |
| **domain-modeling** | Model-invoked | Build and sharpen a project's domain model, ubiquitous language, and record ADRs |
| **grilling** | Model-invoked | Grill the user relentlessly about a plan or design to stress-test it before building |
| **grill-me** | User-invoked (`grill-me`) | Launch a relentless interview to sharpen a plan or design |
| **grill-with-docs** | User-invoked (`grill-with-docs`) | Same interview as grill-me, and also creates docs (ADRs and glossary) as it runs |
| **grok** | User-invoked (`grok`) | Conversational path to shared understanding, gated by a teach-back; passing lessons persist to `~/.claude/lessons/` |
| **review-pr** | User-invoked (`review-pr`) | Review a PR in an isolated worktree — investigate and verify the change against the code, surface concerns before it merges |
| **writing-great-skills** | User-invoked (`writing-great-skills`) | Reference for writing and editing skills well |

### Commands (10)

Slash commands live in `claude/.claude/commands/` and are always user-invoked.

| Command | Purpose |
|---------|---------|
| **`/commit`** | Create strictly atomic commits — one logical change per commit |
| **`/crufthard`** | Delete unused exports (cruft) with typetest verification and auto-revert |
| **`/cruftsoft`** | Identify unused exports (cruft) and report with rationale |
| **`/document`** | Generate comprehensive CDK infrastructure documentation — architecture diagrams, README, and service docs |
| **`/merge`** | Resolve git merge conflicts intelligently after pulling from main |
| **`/schemacheck`** | Audit for GraphQL schema drift and forbidden patterns — ships with project-specific defaults from another codebase (a "Build Queue services" example), so adapt it before relying on it here |
| **`/tfork [h\|j\|k\|l]`** | Fork this session into an adjacent tmux pane (default right) or a new terminal window |
| **`/trestart`** | Restart this session in place — continue in the same tmux pane, or relocate it to a new terminal window |
| **`/typetest`** | Progressive sweep demanding improvement in TypeScript errors, test failures, and coverage until targets are met |
| **`/workreport`** | Generate a structured work report summarizing task, changes, and verification steps |

### Documentation Hierarchy

Two tiers: **project `CLAUDE.md`** (technical context for agents — TDD workflow, orchestration rules, standards, commit conventions — the primary output for any change) and **this README** (overview for humans). New `.md` files are not created without explicit approval; there is no separate `docs/` tree.

### MCP Servers (7)

| Server | Purpose | Key Features |
|--------|---------|--------------|
| **context7** | Library Documentation | Up-to-date docs for npm packages, Python libraries |
| **sequential-thinking** | Problem Solving | Structured reasoning, complex problem decomposition |
| **puppeteer** | Browser Automation | Web testing, scraping, browser interaction |
| **browser-tools** | Browser Automation | Browser console/network inspection, audits |
| **aws-cdk** | AWS Infrastructure | CloudFormation validation, CDK docs, deployment troubleshooting |
| **serena** | Semantic Code Tools | IDE-grade, symbol-level code navigation and editing via LSP |
| **headroom** | Context Compression | Compresses tool output to reduce token usage |

### Installation Scripts

- **`install.sh`**: Master installer orchestrating the entire setup
- **`scripts/install-claude-code.sh`**: Claude CLI installation
- **`scripts/install-claude-mem.sh`**: claude-mem plugin + memory worker setup (requires Bun)
- **`scripts/install-headroom.sh`**: Headroom compression proxy setup (requires uv)
- **`scripts/setup-mcp.sh`**: MCP server configuration deployment
- **`scripts/list-mcp-tools.sh`**: MCP tools verification
- **`scripts/clean-ephemeral.sh`**: Removes machine-local session/task data from `~/.claude`
- **`scripts/utils.sh`**: Shared utility functions

### Output Style (Default: Terse)

`claude/.claude/output-styles/terse.md` ships one output style, **Terse** (`settings.json` sets `"outputStyle": "Terse"`, so it's on by default for anyone installing this config). It compresses responses to one point per response, drops filler and preamble, and enforces absolute file paths — it does not change tool use or capability, only how responses are written. Toggle it with "stop caveman" / "normal mode", or by editing `outputStyle` in `~/.claude/settings.json`.

---

## 🚀 Quick Start

```bash
# Clone repository
git clone https://github.com/yourusername/dotclaude.git ~/.dotclaude
cd ~/.dotclaude

# Run installation
./install.sh

# Configure API keys
vim .env.mcp.local  # create with CONTEXT7_API_KEY=... (see Configuration below)
./scripts/setup-mcp.sh

# Verify setup
claude
```

---

## ⚙️ Installation

### Prerequisites

**None.** The installation script handles all dependencies automatically:
- GNU stow (for symlink management)
- gettext / envsubst (for MCP config templating)
- Node.js & npm (for MCP servers)
- Bun (for the claude-mem memory worker)
- uv (for the Headroom proxy and the aws-cdk MCP server, both run via `uvx`)
- Claude Code CLI

### Full Installation Process

```bash
# 1. Clone repository
git clone https://github.com/yourusername/dotclaude.git ~/.dotclaude
cd ~/.dotclaude

# 2. Run installer
./install.sh
```

### What the Install Script Does

1. **Environment Check**: Verifies operating system and shell
2. **Dependency Installation**: Installs GNU stow, Node.js, gettext, Bun, and uv if missing
3. **Backup Creation**: Backs up existing `~/.claude` configuration (timestamped)
4. **Symlink Management**: Uses `stow` to create symlinks
5. **Claude CLI Installation**: Installs Claude Code CLI via `install-claude-code.sh`
6. **MCP Configuration**: Deploys MCP server config automatically via `setup-mcp.sh`
7. **Additional Tool Setup**: Configures the Headroom proxy, claude-mem, Serena, and the `claude-bare` launcher (each self-guards and skips if its prerequisites are missing)
8. **Verification**: Tests the installation and displays status

### Installation Flags

```bash
./install.sh --help              # Show help
./install.sh --skip-deps         # Skip dependency checks
./install.sh --no-backup         # Don't backup existing config
```

### Post-Installation Steps

#### 1. Configure API Keys

```bash
# Create the local secrets file (gitignored, no tracked template to copy)
vim .env.mcp.local  # or nano, code, etc.
```

Add your API key:
- **CONTEXT7_API_KEY**: From [Upstash Console](https://console.upstash.com)

`setup-mcp.sh` warns and disables `context7` if this is missing — all other servers work without any keys.

#### 2. Deploy MCP Configuration

```bash
./scripts/setup-mcp.sh
```

#### 3. Verify Setup

```bash
# Start Claude Code
claude

# Inside Claude, verify agents loaded:
# Check the response mentions "Main Agent" and agent orchestration

# Verify MCP servers
./scripts/list-mcp-tools.sh
```

---

## 📁 Directory Structure

```
dotclaude/
├── .gitignore                    # Whitelist strategy (ignores everything by default)
├── README.md                     # This file
├── install.sh                    # Master installation orchestrator
├── .env.mcp.local                # API keys (gitignored, created locally — no tracked template)
│
├── mcp/
│   └── mcp.json.template         # MCP server configuration template
│
├── serena/
│   └── serena_config.yml         # Serena MCP server config (symlinked to ~/.serena/)
│
├── scripts/
│   ├── install-claude-code.sh    # Claude CLI installer
│   ├── install-claude-mem.sh     # claude-mem plugin/memory worker setup
│   ├── install-headroom.sh       # Headroom proxy setup
│   ├── setup-mcp.sh              # MCP configuration deployer
│   ├── list-mcp-tools.sh         # MCP tools verification
│   ├── clean-ephemeral.sh        # Removes machine-local ~/.claude session data
│   └── utils.sh                  # Shared utility functions
│
└── claude/                       # Stow package (source)
    └── .claude/                  # Becomes ~/.claude (target)
        ├── CLAUDE.md             # Main Agent instructions (primary documentation output)
        ├── settings.json         # Claude Code settings
        │
        ├── agents/               # 12 specialized agent definitions
        │   ├── technical-architect.md
        │   ├── test-writer.md
        │   ├── typescript-connoisseur.md
        │   ├── quality-refactoring-specialist.md
        │   ├── production-readiness-specialist.md
        │   ├── backend-typescript-specialist.md
        │   ├── git-specialist.md
        │   ├── shell-specialist.md
        │   ├── react-engineer.md
        │   ├── documentation-specialist.md
        │   ├── task-explorer.md
        │   └── subtask-list-generator.md
        │
        ├── skills/               # 8 skills (each a directory with a SKILL.md)
        │   ├── docs-drift/
        │   ├── domain-modeling/
        │   ├── grilling/
        │   ├── grill-me/
        │   ├── grill-with-docs/
        │   ├── grok/
        │   ├── review-pr/
        │   └── writing-great-skills/
        │
        ├── commands/             # 10 slash commands
        │   ├── commit.md
        │   ├── crufthard.md
        │   ├── cruftsoft.md
        │   ├── document.md
        │   ├── merge.md
        │   ├── schemacheck.md
        │   ├── tfork.md
        │   ├── trestart.md
        │   ├── typetest.md
        │   └── workreport.md
        │
        └── output-styles/        # Default-on Terse output style
            └── terse.md
```

---

## 🏗️ Architecture

### Stow-Based Symlink Management

**dotclaude** uses **GNU stow** for elegant configuration management:

- **Package**: `claude/` directory (source)
- **Target**: `~/.claude/` (destination)
- **Method**: Stow creates symlinks from target to source

**Example:**
```
~/.claude/CLAUDE.md -> ~/.dotclaude/claude/.claude/CLAUDE.md
~/.claude/agents/   -> ~/.dotclaude/claude/.claude/agents/
```

### Why Symlinks?

1. **Version Control**: All changes in git-tracked source
2. **Easy Updates**: `git pull` updates live configuration
3. **Portability**: Clone and stow on any machine
4. **Atomic Changes**: Stow handles conflicts and cleanup
5. **No Manual Copies**: Changes propagate automatically

### How Stow Works

```bash
# From ~/.dotclaude directory:
stow claude

# Stow creates:
# ~/.claude -> ~/.dotclaude/claude/.claude
# (symlinks all contents)

# To remove:
stow -D claude
```

---

## 🤖 Specialized Agents

### Technical Architect
**Domain**: Planning & Design
**Invoked For**: Complex features, task breakdown, multi-session features
**Returns**: WIP.md with testable tasks, acceptance criteria, architectural decisions

### Test Writer
**Domain**: Testing & TDD
**Invoked For**: Writing tests, coverage verification, behavioral testing
**Returns**: Failing tests (RED), test coverage reports, test quality assessment

### TypeScript Connoisseur
**Domain**: Type Systems
**Invoked For**: Advanced TypeScript, Zod schema design, strict mode compliance
**Returns**: Type definitions, schema designs, type safety improvements

### Quality & Refactoring Specialist
**Domain**: Code Review & Quality
**Invoked For**: Post-GREEN refactoring, code review, tier-based standards enforcement
**Returns**: Refactoring recommendations, quality assessment, clean code

### Production Readiness Specialist
**Domain**: Security & Performance
**Invoked For**: Security audits, OWASP compliance, performance profiling, deployment readiness
**Returns**: Vulnerability reports, performance metrics, readiness checklists

### Backend TypeScript Specialist
**Domain**: Backend Development
**Invoked For**: Contract-first API/database design, REST/GraphQL, Lambda, DynamoDB, indexing strategies
**Returns**: API implementations, database schemas, backend services

### Git Specialist
**Domain**: Version Control
**Invoked For**: Local commits, branches, history operations
**Returns**: Commits with conventional messages — never pushes to remote or opens PRs

### Shell Specialist
**Domain**: Automation
**Invoked For**: Shell script implementation, system automation, git hook bodies, CI/CD scripts
**Returns**: Robust, idempotent, tested shell scripts

### React Engineer
**Domain**: Frontend Development
**Invoked For**: React 19+, Next.js App Router, Remix, hooks, SSR
**Returns**: React implementations, component designs, frontend logic

### Documentation Specialist
**Domain**: Documentation
**Invoked For**: Project documentation, ADRs, quality audits, learning capture
**Returns**: Updated documentation, ADRs, CLAUDE.md updates

### Task Explorer
**Domain**: Codebase Onboarding
**Invoked For**: Picking up a new ticket, understanding an unfamiliar code area
**Returns**: Read-only context report — relevant files, architecture, data flows, patterns

### Subtask List Generator
**Domain**: Bulk Fixes
**Invoked For**: Standardisation tasks, migrations, fixes spanning many files
**Returns**: Exhaustive checklist file for domain agents to work through

---

## 📚 Documentation Structure

There is no separate `docs/` tree. All TDD workflow, orchestration rules, standards, and patterns that used to live as split reference files now live in a single **`claude/.claude/CLAUDE.md`** (the primary documentation output for any change). This README covers repository setup and usage; CLAUDE.md covers how the agents work.

---

## 🌐 MCP Servers

### context7
**Purpose**: Up-to-date library documentation
**Use Cases**: Check latest npm package APIs, Python library docs, framework updates
**API Key**: Upstash (Context7)

### sequential-thinking
**Purpose**: Structured problem-solving
**Use Cases**: Complex debugging, architectural decisions, algorithm design
**API Key**: None (uses Claude's built-in reasoning)

### puppeteer
**Purpose**: Browser automation
**Use Cases**: E2E testing, web scraping, browser interaction testing
**API Key**: None (local browser control)

### browser-tools
**Purpose**: Browser console/network inspection
**Use Cases**: Audits, debugging client-side issues via a running browser session
**API Key**: None (local browser control)

### aws-cdk
**Purpose**: AWS Infrastructure as Code
**Use Cases**: CloudFormation validation/compliance, CDK construct docs, deployment troubleshooting
**API Key**: None (knowledge-based)

### serena
**Purpose**: Semantic, symbol-level code tools via LSP
**Use Cases**: `find_symbol`, `find_referencing_symbols`, safe rename/inline refactors
**API Key**: None (local language server)

### headroom
**Purpose**: Context compression proxy
**Use Cases**: Reduces token usage on large tool outputs
**API Key**: None (local proxy, requires `uv`)

---

## 🔧 Configuration

### API Keys

1. **Create local environment file** (gitignored, no tracked template):
   ```bash
   vim .env.mcp.local
   ```

2. **Add your API key:**
   ```bash
   # .env.mcp.local
   CONTEXT7_API_KEY=ctx7sk-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ```

3. **Deploy MCP configuration:**
   ```bash
   ./scripts/setup-mcp.sh
   ```

### MCP Setup

The `setup-mcp.sh` script:
1. Reads `.env.mcp.local`
2. Injects API keys into `mcp.json.template`
3. Writes `~/.mcp.json` with configured servers
4. Validates JSON syntax

### Verification

#### Check Claude Code is installed:
```bash
claude --version
```

#### Check agents are loaded:
```bash
claude
# In Claude, ask: "What specialized agents are available?"
```

#### Check MCP servers:
```bash
./scripts/list-mcp-tools.sh
```

Expected output:
```
MCP Tools Available:
  - context7: get_context
  - sequential-thinking: think
  - puppeteer: navigate, click, screenshot
  - browser-tools: getConsoleLogs, getNetworkLogs, runAudit
  - aws-cdk: search_cdk_documentation, validate_cloudformation_template
  - serena: find_symbol, find_referencing_symbols, replace_symbol_body
  - headroom: (transparent proxy — no directly invoked tools)
```

---

## 💻 Usage

### Starting Claude Code

```bash
# Start interactive session
claude

# With specific prompt
claude "Review this code for security issues"

# In project directory
cd ~/projects/myapp
claude
```

### Verifying Agents Loaded

Inside Claude Code:
```
You: "What agents are available?"

Claude: "I have access to 12 specialized agents:
- Technical Architect (planning)
- Test Writer (TDD)
- ..."
```

### Checking MCP Servers

```bash
# List all available MCP tools
./scripts/list-mcp-tools.sh

# Test context7
claude "Use context7 to check the latest React 19 API"

# Test serena
claude "Use serena to find references to this symbol"
```

### Common Commands

```bash
# Update configuration
cd ~/.dotclaude
git pull
stow -R claude  # Restow to refresh symlinks

# Check symlink status
ls -la ~/.claude

# View agent definitions
ls ~/.claude/agents/

# Read documentation
cat ~/.claude/CLAUDE.md

# Check MCP config
cat ~/.mcp.json
```

### Fallback Launcher: `claude-bare`

Runs Claude Code with an isolated config dir so your normal `~/.claude` is never touched — useful when your config is broken or you want a clean-room debug session.

```bash
# Run Claude Code against an isolated config (default: ~/.claude-bare)
claude-bare

# Forward any args you'd normally pass to claude
claude-bare "Explain this error" --model claude-opus-4-5

# Use a custom config dir for this run only
CLAUDE_BARE_DIR=~/claude-test claude-bare
```

**How it works**: `claude-bare` calls `exec env CLAUDE_CONFIG_DIR=~/.claude-bare claude [args...]`. The env var applies only to that process; your next plain `claude` call uses your normal `~/.claude` as usual. Nothing is written to your shell rc.

**Persistent bare dir**: `~/.claude-bare` is reused across runs, so you authenticate once and the fallback keeps working. First run will prompt you to log in.

**Install**: shipped at `bin/claude-bare` in this repo and symlinked to `~/.local/bin/claude-bare` by `install.sh`. Because it's a symlink, edits to `bin/claude-bare` take effect immediately — no shell restart needed. Requires `~/.local/bin` on `$PATH`.

**Use cases**:
- **Config recovery**: your `~/.claude` edits broke something — run `claude-bare` to get a working Claude while you debug
- **Clean-room debugging**: check whether a problem is caused by your customizations vs. Claude Code itself; complement with `claude --safe-mode` (disables CLAUDE.md/agents/skills/hooks/MCP while keeping auth)

---

## 🎨 Customization

### Adding New Agents

1. **Create agent file:**
   ```bash
   touch ~/.dotclaude/claude/.claude/agents/my-custom-agent.md
   ```

2. **Define agent structure:**
   ```markdown
   # My Custom Agent

   ## Purpose
   What this agent does

   ## When to Invoke
   Situations requiring this agent

   ## Capabilities
   - Capability 1
   - Capability 2

   ## Process
   How this agent works
   ```

3. **Reference in CLAUDE.md:**
   Edit `~/.claude/CLAUDE.md` to add agent to orchestration system

### Modifying Documentation

Documentation lives in `~/.claude/CLAUDE.md` — there is no separate `docs/` tree:
```bash
# Edit project documentation
vim ~/.claude/CLAUDE.md

# Changes automatically reflected (symlinks)
```

New standalone `.md` files are not created without explicit user approval.

### Adding MCP Servers

1. **Install MCP server:**
   ```bash
   npm install -g @new-mcp-server/package
   ```

2. **Edit template:**
   ```bash
   vim ~/.dotclaude/mcp/mcp.json.template
   ```

3. **Add server configuration:**
   ```json
   {
     "mcpServers": {
       "my-server": {
         "command": "npx",
         "args": ["-y", "@my-server/package"],
         "env": {
           "API_KEY": "${MY_SERVER_API_KEY}"
         }
       }
     }
   }
   ```

4. **Add environment variable:**
   ```bash
   echo "MY_SERVER_API_KEY=your_key_here" >> .env.mcp.local
   ```

5. **Redeploy:**
   ```bash
   ./scripts/setup-mcp.sh
   ```

### Custom Settings

Edit `~/.claude/settings.json`:
```json
{
  "model": "claude-opus-4-5",
  "outputStyle": "Terse",
  "effortLevel": "high",
  "includeCoAuthoredBy": false
}
```

Changes are immediate (symlinks).

---

## 🔗 Relationship to Dotfiles

**dotclaude is completely independent.**

### Can Be Used:

✅ **Standalone**: Without any dotfiles
✅ **With Dotfiles**: Alongside existing dotfiles
✅ **In dotfiles**: As a submodule (optional)

### Independence:

- **No Dependencies**: dotclaude doesn't require dotfiles
- **No Conflicts**: Separate configuration space (`~/.claude`)
- **Clean Separation**: Version control, installation, updates all independent

### Integration Options:

**Option 1: Standalone** (Recommended)
```bash
git clone https://github.com/you/dotclaude.git ~/.dotclaude
cd ~/.dotclaude && ./install.sh
```

**Option 2: Alongside Dotfiles**
```bash
# Dotfiles
git clone https://github.com/you/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./install

# dotclaude (separate)
git clone https://github.com/you/dotclaude.git ~/.dotclaude
cd ~/.dotclaude && ./install.sh
```

**Option 3: Submodule in Dotfiles** (Advanced)
```bash
cd ~/.dotfiles
git submodule add https://github.com/you/dotclaude.git claude
# Add to dotfiles installation script:
# cd claude && ./install.sh
```

Choose based on your preference. All options work equally well.

---

## 🗑️ Uninstallation

### Remove Symlinks

```bash
cd ~/.dotclaude
stow -D claude
```

This removes all symlinks in `~/.claude/` but preserves the source in `~/.dotclaude/`.

### Restore Backup

If you had existing configuration, restore the backup:

```bash
# List backups
ls -la ~ | grep .claude.backup

# Restore specific backup
mv ~/.claude.backup.20250114-153000 ~/.claude
```

### Remove MCP Configuration

```bash
rm ~/.mcp.json
```

### Complete Removal

```bash
# Remove dotclaude repository
rm -rf ~/.dotclaude

# Remove Claude Code CLI (optional)
npm uninstall -g @anthropic-ai/claude-code

# Remove all Claude configuration
rm -rf ~/.claude
rm ~/.mcp.json
```

---

## 🔍 Troubleshooting

### Symlink Conflicts

**Problem**: `stow: WARNING! stowing claude would cause conflicts`

**Solution**:
```bash
# Backup existing config
mv ~/.claude ~/.claude.backup.$(date +%Y%m%d-%H%M%S)

# Retry stow
stow claude
```

### Missing Dependencies

**Problem**: `stow: command not found`

**Solution**:
```bash
# macOS
brew install stow

# Linux (Debian/Ubuntu)
sudo apt-get install stow

# Linux (Arch)
sudo pacman -S stow
```

### MCP Server Issues

**Problem**: MCP servers not loading

**Diagnosis**:
```bash
# Check MCP config exists
cat ~/.mcp.json

# Validate JSON syntax
python3 -m json.tool ~/.mcp.json

# Check environment variables
cat ~/.dotclaude/.env.mcp.local
```

**Solution**:
```bash
# Redeploy MCP configuration
cd ~/.dotclaude
./scripts/setup-mcp.sh

# Verify
./scripts/list-mcp-tools.sh
```

### API Key Issues

**Problem**: MCP servers failing with authentication errors

**Solution**:
```bash
# Verify keys are in local file (not template)
cat .env.mcp.local  # Should have actual keys

# Check key is valid format
# Context7: ctx7sk-xxxx-xxxx-xxxx-xxxx

# Redeploy after fixing
./scripts/setup-mcp.sh
```

### Claude Code Not Found

**Problem**: `claude: command not found`

**Solution**:
```bash
# Install Claude CLI
cd ~/.dotclaude
./scripts/install-claude-code.sh

# Verify installation
claude --version

# Check PATH
echo $PATH | grep -q "$HOME/.local/bin" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Agent Not Loading

**Problem**: Agent not available in Claude Code

**Diagnosis**:
```bash
# Check agent file exists
ls -la ~/.claude/agents/

# Check symlinks are correct
ls -la ~/.claude | grep agents

# Check CLAUDE.md references agent
grep -i "agent-name" ~/.claude/CLAUDE.md
```

**Solution**:
```bash
# Restow to refresh symlinks
cd ~/.dotclaude
stow -R claude

# Restart Claude Code
```

### Logs Location

```bash
# Claude Code logs
~/.claude/logs/

# MCP server logs
~/.mcp/logs/

# Installation logs
~/.dotclaude/install.log
```

---

## 🤝 Contributing

### Reporting Issues

1. **Check existing issues**: [GitHub Issues](https://github.com/yourusername/dotclaude/issues)
2. **Provide details**:
   - Operating system and version
   - Shell (zsh, bash)
   - Error messages (full output)
   - Steps to reproduce
3. **Include logs**:
   ```bash
   # Installation issues
   cat ~/.dotclaude/install.log

   # Runtime issues
   cat ~/.claude/logs/latest.log
   ```

### Adding Documentation

1. **Create branch**:
   ```bash
   cd ~/.dotclaude
   git checkout -b docs/my-addition
   ```

2. **Add documentation**:
   ```bash
   # Project CLAUDE.md is the primary documentation output
   vim claude/.claude/CLAUDE.md
   ```

3. **Follow structure**:
   - Clear headings
   - Code examples
   - Real-world use cases
   - Links to related docs

4. **Submit PR**:
   ```bash
   git add .
   git commit -m "docs: add workflow for X"
   git push origin docs/my-addition
   ```

### Agent Modification Guidelines

**DO:**
- Keep agent purpose focused and clear
- Provide concrete examples
- Document when to invoke
- Specify return expectations
- Link to relevant documentation

**DON'T:**
- Make agents too broad (single responsibility)
- Duplicate capabilities across agents
- Reference non-existent documentation
- Use ambiguous language

**Template:**
```markdown
# Agent Name

## Purpose
One sentence describing agent's role

## When to Invoke
- Situation 1
- Situation 2

## Capabilities
- What agent can do
- Tools and knowledge available

## Process
1. Step 1
2. Step 2

## Examples
Concrete usage examples

## Related Agents
Links to related agents
```

---

## 📄 License

**MIT License**

Copyright (c) 2025 [Your Name]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## 🙏 Acknowledgments

- **Anthropic**: Claude Code and Claude API
- **MCP Protocol**: Model Context Protocol specification
- **GNU Stow**: Symlink management system
- **TDD Community**: Test-driven development best practices
- **Open Source Community**: Inspiration and patterns

---

## 🔗 Links

- **Documentation**: [~/.claude/CLAUDE.md](./claude/.claude/CLAUDE.md)
- **Issues**: [GitHub Issues](https://github.com/yourusername/dotclaude/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/dotclaude/discussions)
- **Claude Code**: [Anthropic Claude Code](https://www.anthropic.com)
- **MCP Protocol**: [Model Context Protocol](https://modelcontextprotocol.io)

---

**Built with ❤️ for developers who value TDD, clean code, and AI-augmented development.**

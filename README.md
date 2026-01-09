# ✨ dotclaude

> **A standalone, production-ready Claude Code configuration system with specialized AI agents, comprehensive documentation, and automated MCP server setup.**

---

## 📖 Overview

**dotclaude** is a complete Claude Code configuration repository that implements a sophisticated multi-agent development system. It provides:

- **13 Specialized AI Agents**: Each agent is an expert in a specific domain (testing, architecture, security, etc.)
- **Test-Driven Development Framework**: Non-negotiable TDD with Red-Green-Refactor cycle
- **Comprehensive Documentation**: Organized workflows, references, patterns, and examples
- **MCP Server Integration**: 6 pre-configured Model Context Protocol servers for enhanced capabilities
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

### Specialized Agents (13)

| Agent | Domain | Purpose |
|-------|--------|---------|
| **Technical Architect** | Planning & Design | Task breakdown, feature planning, WIP management |
| **Test Writer** | Testing & TDD | Behavioral tests, coverage verification, TDD cycle |
| **TypeScript Connoisseur** | Type Systems | Advanced TypeScript, Zod schemas, strict mode |
| **Code Quality & Refactoring Specialist** | Code Review | Quality assessment, refactoring guidance, git operations |
| **Security & Performance Specialist** | Security & Optimization | OWASP compliance, vulnerability scanning, performance profiling |
| **Backend TypeScript Specialist** | Backend Development | REST/GraphQL APIs, Lambda functions, database integration |
| **Database Design Specialist** | Data Modeling | Schema design, migrations, query optimization |
| **Git & Shell Specialist** | Version Control | Git workflows, commits, PRs, shell scripting, automation |
| **React Engineer** | Frontend Development | React components, hooks, SSR, client-side state |
| **AWS CDK Expert** | Infrastructure | CDK stacks, AWS resources, IaC best practices |
| **Documentation Agent** | Documentation | Project docs, ADRs, API documentation, learning capture |
| **Design Specialist** | API & Schema Design | Contract-first design, API specifications |
| **Production Readiness Specialist** | Deployment | Pre-production audits, reliability, monitoring |

### Documentation Hierarchy

```
docs/
├── workflows/          # Development processes
│   ├── tdd-cycle.md             # Red-Green-Refactor cycle
│   ├── agent-collaboration.md   # Agent orchestration patterns
│   └── code-review.md           # Review workflows
├── references/         # Quick lookups
│   ├── standards-checklist.md   # Quality gates
│   └── code-style.md            # Style guide
├── patterns/          # Domain patterns
│   ├── typescript/             # TS patterns
│   ├── react/                  # React patterns
│   ├── backend/                # Backend patterns
│   ├── refactoring/            # Refactoring patterns
│   ├── security/               # Security patterns
│   └── performance/            # Performance patterns
└── examples/          # Concrete examples
    └── (walkthroughs and case studies)
```

### MCP Servers (6)

| Server | Purpose | Key Features |
|--------|---------|--------------|
| **context7** | Library Documentation | Up-to-date docs for npm packages, Python libraries |
| **taskmaster** | Task Management | AI-powered task tracking, prioritization, progress monitoring |
| **sequential-thinking** | Problem Solving | Structured reasoning, complex problem decomposition |
| **playwright** | Browser Automation | Web testing, scraping, browser interaction |
| **aws-core** | AWS Expertise | AWS service guidance, best practices |
| **aws-cdk** | AWS CDK | Infrastructure as Code, CDK patterns |

### Installation Scripts

- **`install.sh`**: Master installer orchestrating the entire setup
- **`scripts/install-claude-code.sh`**: Claude CLI installation
- **`scripts/setup-mcp.sh`**: MCP server configuration deployment
- **`scripts/list-mcp-tools.sh`**: MCP tools verification
- **`scripts/utils.sh`**: Shared utility functions

### Profile Management Scripts

dotclaude supports multiple configuration profiles, allowing you to switch between different agent configurations, documentation sets, and settings.

| Script | Location | Purpose |
|--------|----------|---------|
| **`list-profiles.sh`** | `scripts/list-profiles.sh` | List all available profiles with status and statistics |
| **`switch-profile.sh`** | `scripts/switch-profile.sh` | Switch the active profile by updating symlinks |
| **`add-profile.sh`** | `scripts/add-profile.sh` | Add an external profile repository as a git submodule |
| **`migrate-to-profiles.sh`** | `scripts/migrate-to-profiles.sh` | Migrate from legacy structure to the profiles system |

#### Profile Commands

```bash
# List all available profiles
./scripts/list-profiles.sh

# Switch to a different profile
./scripts/switch-profile.sh <profile-name>
./scripts/switch-profile.sh default

# Force switch (overwrites existing symlinks)
./scripts/switch-profile.sh --force <profile-name>

# Switch to an external profile
./scripts/switch-profile.sh external/someone-config

# Add an external profile from a git repository
./scripts/add-profile.sh https://github.com/user/their-dotclaude.git

# Add with custom name
./scripts/add-profile.sh https://github.com/user/their-dotclaude.git custom-name

# Add from a repo where .claude/ is in a subdirectory
./scripts/add-profile.sh --subpath claude https://github.com/user/dotfiles.git my-profile
```

#### Profile Directory Structure

```
profiles/
├── default/              # Built-in default profile
│   └── .claude/
│       ├── CLAUDE.md
│       ├── settings.json
│       ├── agents/
│       ├── commands/
│       ├── docs/
│       └── plugins/
└── external/             # External profiles (git submodules)
    ├── team-config/      # Example: team shared config
    │   └── .claude/
    └── experimental/     # Example: experimental setup
        └── .claude/

runtime/                  # Shared runtime data (not profile-specific)
├── cache/
├── debug/
├── file-history/
├── logs/
└── projects/
```

#### How Profiles Work

1. **Config items** (CLAUDE.md, agents/, docs/, etc.) are symlinked from the active profile's `.claude/` directory to `~/.claude/`
2. **Runtime items** (cache, logs, projects) are shared across all profiles via the `runtime/` directory
3. Switching profiles updates symlinks instantly - no file copying required
4. External profiles are managed as git submodules for easy updates

---

## 🚀 Quick Start

```bash
# Clone repository
git clone https://github.com/yourusername/dotclaude.git ~/.dotclaude
cd ~/.dotclaude

# Run installation
./install.sh

# Configure API keys
cp .env.mcp .env.mcp.local
# Edit .env.mcp.local with your actual keys
./scripts/setup-mcp.sh

# Verify setup
claude
```

---

## ⚙️ Installation

### Prerequisites

**None.** The installation script handles all dependencies automatically:
- GNU stow (for symlink management)
- Node.js & npm (for MCP servers)
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
2. **Dependency Installation**: Installs GNU stow if missing
3. **Backup Creation**: Backs up existing `~/.claude` configuration (timestamped)
4. **Symlink Management**: Uses `stow` to create symlinks
5. **Claude CLI Installation**: Installs Claude Code CLI via `install-claude-code.sh`
6. **MCP Setup Prompt**: Offers to configure MCP servers
7. **Verification**: Tests the installation and displays status

### Installation Flags

```bash
./install.sh --help              # Show help
./install.sh --skip-deps         # Skip dependency checks
./install.sh --no-backup         # Don't backup existing config
./install.sh --skip-claude-cli   # Skip Claude CLI installation
```

### Post-Installation Steps

#### 1. Configure API Keys

```bash
# Copy template
cp .env.mcp .env.mcp.local

# Edit with your keys
vim .env.mcp.local  # or nano, code, etc.
```

Add your API keys:
- **CONTEXT7_API_KEY**: From [Upstash Console](https://console.upstash.com)
- **ANTHROPIC_API_KEY**: From [Anthropic Console](https://console.anthropic.com)

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
├── .env.mcp                      # API key template (copy to .env.mcp.local)
│
├── mcp/
│   └── mcp.json.template         # MCP server configuration template
│
├── scripts/
│   ├── install-claude-code.sh    # Claude CLI installer
│   ├── setup-mcp.sh              # MCP configuration deployer
│   ├── list-mcp-tools.sh         # MCP tools verification
│   └── utils.sh                  # Shared utility functions
│
└── claude/                       # Stow package (source)
    └── .claude/                  # Becomes ~/.claude (target)
        ├── CLAUDE.md             # Main Agent instructions
        ├── CHANGELOG_TEMPLATE.md # Keep A Changelog template
        ├── settings.json         # Claude Code settings
        │
        ├── agents/               # 13 specialized agent definitions
        │   ├── technical-architect.md
        │   ├── test-writer.md
        │   ├── typescript-connoisseur.md
        │   ├── code-quality-refactoring-specialist.md
        │   ├── security-performance-specialist.md
        │   ├── backend-typescript-specialist.md
        │   ├── database-design-specialist.md
        │   ├── git-shell-specialist.md
        │   ├── react-engineer.md
        │   ├── design-specialist.md
        │   ├── documentation-agent.md
        │   ├── production-readiness-specialist.md
        │   └── quality-refactoring-specialist.md
        │
        ├── docs/                 # Documentation hierarchy
        │   ├── workflows/        # Development workflows
        │   ├── references/       # Quick references
        │   ├── patterns/         # Domain-specific patterns
        │   └── examples/         # Concrete examples
        │
        └── plugins/              # Plugin configuration
            └── tmux/             # Tmux integration
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

### Code Quality & Refactoring Specialist
**Domain**: Code Review & Quality
**Invoked For**: Post-GREEN refactoring, code review, pattern enforcement
**Returns**: Refactoring recommendations, quality assessment, clean code

### Security & Performance Specialist
**Domain**: Security & Optimization
**Invoked For**: Security audits, OWASP compliance, performance profiling
**Returns**: Vulnerability reports, performance metrics, optimization recommendations

### Backend TypeScript Specialist
**Domain**: Backend Development
**Invoked For**: REST/GraphQL APIs, Lambda functions, backend logic
**Returns**: API implementations, database integrations, backend services

### Database Design Specialist
**Domain**: Data Modeling
**Invoked For**: Schema design BEFORE implementation
**Returns**: Database schemas, migration scripts, query optimizations

### Git & Shell Specialist
**Domain**: Version Control & Automation
**Invoked For**: Git operations, commits, PRs, shell scripts, git hooks
**Returns**: Commits with conventional messages, PRs, shell automation

### React Engineer
**Domain**: Frontend Development
**Invoked For**: React components, hooks, SSR, client-side state
**Returns**: React implementations, component designs, frontend logic

### AWS CDK Expert
**Domain**: Infrastructure as Code
**Invoked For**: CDK stacks, AWS resources, infrastructure deployment
**Returns**: CDK stack definitions, AWS resource configurations

### Documentation Agent
**Domain**: Documentation
**Invoked For**: Project documentation, ADRs, API docs, learning capture
**Returns**: Updated documentation, ADRs, CLAUDE.md updates

### Design Specialist
**Domain**: API & Schema Design
**Invoked For**: Contract-first design, API specifications, schema design
**Returns**: API contracts, design documents, schema specifications

### Production Readiness Specialist
**Domain**: Deployment & Operations
**Invoked For**: Pre-production audits, reliability checks, monitoring setup
**Returns**: Readiness reports, deployment checklists, monitoring configurations

---

## 📚 Documentation Structure

### Workflows (`docs/workflows/`)

**Development Process Flows:**
- **`tdd-cycle.md`**: Complete Red-Green-Refactor cycle
- **`agent-collaboration.md`**: Agent orchestration patterns, delegation flows
- **`code-review.md`**: Review workflows, quality gates

### References (`docs/references/`)

**Quick Lookups:**
- **`standards-checklist.md`**: Pre-commit, pre-merge, pre-production checklists
- **`code-style.md`**: Style guide, naming conventions, patterns

### Patterns (`docs/patterns/`)

**Domain-Specific Patterns:**
- **`typescript/`**: TypeScript patterns, Zod schemas, advanced types
- **`react/`**: React patterns, hooks, components, SSR
- **`backend/`**: Backend patterns, APIs, databases, Lambda
- **`refactoring/`**: Refactoring strategies, code smells, improvements
- **`security/`**: Security patterns, OWASP, vulnerability prevention
- **`performance/`**: Performance patterns, optimization, profiling

### Examples (`docs/examples/`)

**Concrete Walkthroughs:**
- Real-world scenarios
- Step-by-step implementations
- Before/after comparisons
- Agent collaboration examples

---

## 🌐 MCP Servers

### context7
**Purpose**: Up-to-date library documentation
**Use Cases**: Check latest npm package APIs, Python library docs, framework updates
**API Key**: Upstash (Context7)

### taskmaster
**Purpose**: AI-powered task management
**Use Cases**: Track complex features, prioritize work, monitor progress
**API Key**: Anthropic

### sequential-thinking
**Purpose**: Structured problem-solving
**Use Cases**: Complex debugging, architectural decisions, algorithm design
**API Key**: None (uses Claude's built-in reasoning)

### playwright
**Purpose**: Browser automation
**Use Cases**: E2E testing, web scraping, browser interaction testing
**API Key**: None (local browser control)

### aws-core
**Purpose**: AWS expert advice
**Use Cases**: Service selection, architecture guidance, AWS best practices
**API Key**: None (knowledge-based)

### aws-cdk
**Purpose**: AWS CDK patterns
**Use Cases**: Infrastructure as Code, CDK constructs, deployment patterns
**API Key**: None (knowledge-based)

---

## 🔧 Configuration

### API Keys

1. **Create local environment file:**
   ```bash
   cp .env.mcp .env.mcp.local
   ```

2. **Add your API keys:**
   ```bash
   # .env.mcp.local
   CONTEXT7_API_KEY=ctx7sk-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ANTHROPIC_API_KEY=sk-ant-api03-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
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
  - taskmaster: create_task, list_tasks, update_task
  - sequential-thinking: think
  - playwright: navigate, click, screenshot
  - aws-core: query
  - aws-cdk: query
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

Claude: "I have access to 13 specialized agents:
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

# Test taskmaster
claude "Create a task to implement user authentication"
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
cat ~/.claude/docs/workflows/tdd-cycle.md

# Check MCP config
cat ~/.mcp.json
```

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

Documentation is markdown files in `~/.claude/docs/`:
```bash
# Edit existing docs
vim ~/.claude/docs/workflows/tdd-cycle.md

# Add new workflow
touch ~/.claude/docs/workflows/my-workflow.md

# Changes automatically reflected (symlinks)
```

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
  "theme": "dark",
  "tabSize": 2,
  "autoSave": true,
  "customSetting": "value"
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

# Check keys are valid format
# Context7: ctx7sk-xxxx-xxxx-xxxx-xxxx
# Anthropic: sk-ant-api03-xxxxxxxxxxxx

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
   # Workflows
   vim claude/.claude/docs/workflows/my-workflow.md

   # Patterns
   vim claude/.claude/docs/patterns/typescript/my-pattern.md
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

- **Documentation**: [~/.claude/docs/](./claude/.claude/docs/)
- **Issues**: [GitHub Issues](https://github.com/yourusername/dotclaude/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/dotclaude/discussions)
- **Claude Code**: [Anthropic Claude Code](https://www.anthropic.com)
- **MCP Protocol**: [Model Context Protocol](https://modelcontextprotocol.io)

---

**Built with ❤️ for developers who value TDD, clean code, and AI-augmented development.**

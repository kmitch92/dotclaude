# CodeRAG Setup Guide

**Complete guide for setting up and using CodeRAG with Claude Code**

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Environment Variables](#environment-variables)
5. [Using CodeRAG](#using-coderag)
6. [Multi-Machine Sync](#multi-machine-sync)
7. [Managing Neo4j](#managing-neo4j)
8. [Troubleshooting](#troubleshooting)
9. [Architecture](#architecture)
10. [Available Tools](#available-tools)

---

## Overview

**What is CodeRAG?**

CodeRAG (Code Retrieval-Augmented Generation) is an enterprise code intelligence platform that creates a searchable knowledge graph of your codebase using Neo4j. It transforms complex software projects into structured graph data, enabling:

- **Intelligent code search** - Find code by functionality, not just text matching
- **Cross-repository analysis** - Understand relationships across multiple projects
- **Architectural insights** - Visualize dependencies, patterns, and technical debt
- **AI-enhanced development** - Provide Claude Code with deep codebase context

**Integration with Claude Code**

CodeRAG integrates with Claude Code via MCP (Model Context Protocol), exposing 23+ powerful tools for code analysis directly in your AI assistant conversations. Claude can:

- Scan local directories or remote repositories (GitHub/GitLab)
- Query code relationships and dependencies
- Analyze architectural patterns and metrics
- Search semantically using natural language
- Track changes across multiple projects

---

## Prerequisites

**Required:**

- **Docker** - For running Neo4j database container
  - Install: https://docs.docker.com/get-docker/
  - Minimum version: Docker 20.10+
  - Docker Compose v2+ (included with Docker Desktop)
- **Node.js 18+** - For running CodeRAG MCP server
  - Install: https://nodejs.org/
  - Verify: `node --version`
- **npm** - Comes with Node.js
  - Verify: `npm --version`
- **~500MB disk space** - For Neo4j data and CodeRAG installation

**Optional:**

- **Docker Hub account** - For multi-machine sync (free tier sufficient)
  - Sign up: https://hub.docker.com/signup
- **GitHub token** - For scanning private repositories
  - Generate: https://github.com/settings/tokens
  - Required scope: `repo` (private) or `public_repo` (public only)

**Verification:**

```bash
# Check all prerequisites at once
docker --version && \
docker compose version && \
node --version && \
npm --version && \
echo "✓ All prerequisites met"
```

---

## Quick Start

**Step 1: Run CodeRAG Setup**

```bash
cd /Users/kiel.mitchell/dotclaude
./scripts/setup-coderag.sh
```

This script will:
- Check all prerequisites (Docker, Node.js, npm, git)
- Initialize CodeRAG git submodule
- Install npm dependencies
- Build TypeScript code
- Create Neo4j data directory at `~/neo4j-coderag`
- Verify environment configuration

**Step 2: Configure Neo4j Password**

Create or edit `.env.mcp.local`:

```bash
# Copy template if it doesn't exist
cp .env.mcp .env.mcp.local

# Edit with your preferred editor
nano .env.mcp.local  # or vim, code, etc.
```

Set a secure password:

```bash
# Required: Choose a strong password
CODERAG_NEO4J_PASSWORD=MySecurePassword123

# Optional: Override default data directory
# CODERAG_DATA_DIR=${HOME}/neo4j-coderag
```

**Security note:** `.env.mcp.local` is gitignored and never committed to version control.

**Step 3: Run MCP Setup**

```bash
./scripts/setup-mcp.sh
```

This configures Claude Code to recognize CodeRAG as an MCP server by adding it to `~/Library/Application Support/Claude/claude_desktop_config.json`.

**Step 4: Restart Claude Code**

1. Quit Claude Code completely (⌘+Q on macOS)
2. Relaunch Claude Code
3. Wait 5-10 seconds for MCP servers to initialize

**Step 5: Verify Installation**

In a new Claude Code conversation:

```
Can you list the CodeRAG tools available?
```

You should see 23+ tools including `scan_dir`, `get_project_summary`, `search_nodes`, etc.

---

## Environment Variables

Configure in `.env.mcp.local` (never commit this file):

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `CODERAG_NEO4J_PASSWORD` | **Yes** | *(none)* | Neo4j database password. Must be set before starting Neo4j. Choose a secure password (8+ characters, mixed case, numbers). |
| `CODERAG_DATA_DIR` | No | `~/neo4j-coderag` | Directory for Neo4j data persistence (data, logs, plugins). Change only if you need custom location. |
| `CODERAG_GITHUB_TOKEN` | No | *(none)* | GitHub personal access token for scanning private repositories. Get from https://github.com/settings/tokens. Required scopes: `repo` (private) or `public_repo` (public only). |
| `CODERAG_OPENAI_API_KEY` | No | *(none)* | OpenAI API key for semantic search with embeddings. Get from https://platform.openai.com/api-keys. Enables natural language code search. |
| `CODERAG_GITLAB_TOKEN` | No | *(none)* | GitLab access token for scanning GitLab repositories. Get from GitLab > Settings > Access Tokens. Required scope: `read_repository`. |
| `CODERAG_GITLAB_HOST` | No | `gitlab.com` | GitLab host for self-hosted instances. Example: `gitlab.mycompany.com`. |

**Example `.env.mcp.local`:**

```bash
# Required
CODERAG_NEO4J_PASSWORD=SuperSecurePass2024!

# Optional integrations
CODERAG_GITHUB_TOKEN=ghp_abc123xyz789...
CODERAG_OPENAI_API_KEY=sk-proj-abc123...

# Optional custom data directory
# CODERAG_DATA_DIR=/Volumes/ExternalDrive/neo4j-data
```

**Security best practices:**

- Use strong passwords (12+ characters, mixed case, numbers, symbols)
- Never commit `.env.mcp.local` to git (already in `.gitignore`)
- Rotate tokens periodically
- Use minimal scopes for GitHub/GitLab tokens

---

## Using CodeRAG

**Basic Workflow:**

1. **Scan a codebase** - Build the knowledge graph
2. **Query the graph** - Ask questions about code structure
3. **Analyze relationships** - Understand dependencies and patterns

**Scanning a Local Directory**

In Claude Code conversation:

```
Scan the project at /path/to/my-project using CodeRAG
```

Claude will use the `scan_dir` tool:
- Detects languages automatically (TypeScript, JavaScript, Java, Python)
- Analyzes code structure (classes, methods, interfaces, dependencies)
- Stores relationships in Neo4j graph database
- Returns summary of scanned files and nodes

**Getting Project Summary**

```
Get a summary of the CodeRAG project
```

Returns:
- Total nodes (classes, methods, packages)
- Total relationships (extends, implements, calls)
- Project metadata (languages, frameworks)
- Quality metrics (if calculated)

**Searching Code**

```
Find all classes that extend BaseController
```

```
Show me all methods that use the User class
```

```
What are the dependencies of the AuthService?
```

**Analyzing Patterns**

```
Identify circular dependencies in the project
```

```
Find classes with high coupling (CBO > 10)
```

```
Show architectural patterns used in this codebase
```

**Remote Repository Scanning**

```
Scan the GitHub repository: https://github.com/user/repo
```

Requires `CODERAG_GITHUB_TOKEN` in `.env.mcp.local` for private repos.

**Semantic Search (Requires OpenAI)**

```
Find code that handles user authentication
```

Uses natural language understanding to find relevant code, even if exact keywords don't match.

---

## Multi-Machine Sync

**Use Case:** Share Neo4j knowledge graph across multiple development machines (laptop, desktop, remote server).

**Method:** Docker Hub image backup/restore

### Backup Database

**Save current Neo4j database to Docker Hub:**

```bash
./scripts/coderag-db-backup.sh backup <dockerhub-user>/<image-name>:<tag>
```

**Example:**

```bash
./scripts/coderag-db-backup.sh backup john/coderag-db:myproject
```

**What happens:**

1. Stops Neo4j container (if running)
2. Commits container state to Docker image
3. Pushes image to Docker Hub
4. Restarts Neo4j container (if it was running)

**Requirements:**

- Docker Hub account (free tier works)
- Logged in: `docker login`

**First-time Docker Hub setup:**

```bash
# Login to Docker Hub
docker login
# Enter username and password when prompted

# Verify login
docker info | grep Username
```

### Restore Database

**Load Neo4j database from Docker Hub on another machine:**

```bash
./scripts/coderag-db-backup.sh restore <dockerhub-user>/<image-name>:<tag>
```

**Example:**

```bash
./scripts/coderag-db-backup.sh restore john/coderag-db:myproject
```

**What happens:**

1. Pulls image from Docker Hub
2. Stops and removes existing Neo4j container (with confirmation)
3. Creates new container from pulled image
4. Starts Neo4j with restored data

**Requirements:**

- Same `CODERAG_NEO4J_PASSWORD` in `.env.mcp.local` on both machines
- Docker Hub access to the image

### Workflow for Multiple Machines

**Laptop → Desktop sync example:**

```bash
# On laptop (after scanning code)
./scripts/coderag-db-backup.sh backup john/coderag-db:latest

# On desktop
./scripts/coderag-db-backup.sh restore john/coderag-db:latest
```

**Project-specific backups:**

```bash
# Different projects, different tags
./scripts/coderag-db-backup.sh backup john/coderag-db:project-alpha
./scripts/coderag-db-backup.sh backup john/coderag-db:project-beta
./scripts/coderag-db-backup.sh backup john/coderag-db:legacy-system
```

**Versioned backups:**

```bash
# Tag with date for version history
./scripts/coderag-db-backup.sh backup john/coderag-db:$(date +%Y%m%d)
```

---

## Managing Neo4j

**Start Neo4j Container:**

```bash
docker compose -f /Users/kiel.mitchell/dotclaude/docker/coderag/docker-compose.yml up -d
```

**Stop Neo4j Container:**

```bash
docker compose -f /Users/kiel.mitchell/dotclaude/docker/coderag/docker-compose.yml down
```

**View Neo4j Logs:**

```bash
docker logs coderag-neo4j
```

**Follow logs in real-time:**

```bash
docker logs -f coderag-neo4j
```

**Check Neo4j Status:**

```bash
docker ps | grep coderag-neo4j
```

**Restart Neo4j:**

```bash
docker restart coderag-neo4j
```

**Neo4j Web Browser:**

Open in your browser: http://localhost:7474

**Login credentials:**
- Username: `neo4j`
- Password: *(value from `CODERAG_NEO4J_PASSWORD` in `.env.mcp.local`)*

**Run Cypher queries directly:**

```cypher
// Count all nodes
MATCH (n) RETURN count(n)

// Find all classes
MATCH (n:Class) RETURN n.name LIMIT 10

// Find dependencies
MATCH (a:Class)-[r:DEPENDS_ON]->(b:Class)
RETURN a.name, b.name
LIMIT 20
```

**Data Persistence:**

Neo4j data is stored in `~/neo4j-coderag/` by default (configurable via `CODERAG_DATA_DIR`):

```
~/neo4j-coderag/
├── data/      # Graph database files
├── logs/      # Neo4j server logs
└── plugins/   # Neo4j plugins (APOC)
```

**Delete all data (fresh start):**

```bash
# Stop Neo4j
docker compose -f /Users/kiel.mitchell/dotclaude/docker/coderag/docker-compose.yml down

# Delete data directory
rm -rf ~/neo4j-coderag

# Recreate and restart
./scripts/setup-coderag.sh
```

---

## Troubleshooting

### Neo4j Won't Start

**Symptom:** Docker container exits immediately, `docker ps` shows no `coderag-neo4j`.

**Check logs:**

```bash
docker logs coderag-neo4j
```

**Common causes:**

**1. Password not configured**

```
Error: CODERAG_NEO4J_PASSWORD is not set
```

**Fix:**
```bash
# Set password in .env.mcp.local
echo "CODERAG_NEO4J_PASSWORD=YourSecurePassword" >> .env.mcp.local
```

**2. Port conflicts (7474 or 7687 already in use)**

```
Error: bind: address already in use
```

**Check what's using the port:**
```bash
lsof -i :7474
lsof -i :7687
```

**Fix:** Stop conflicting service or change Neo4j ports in `docker/coderag/docker-compose.yml`.

**3. Permission issues**

```
Error: permission denied
```

**Fix:**
```bash
# Ensure data directory is writable
chmod -R 755 ~/neo4j-coderag
```

### CodeRAG Not Appearing in Claude Code

**Symptom:** Claude Code doesn't show CodeRAG tools or says "CodeRAG not available".

**1. Check password configuration:**

```bash
grep CODERAG_NEO4J_PASSWORD ~/.claude/dotclaude/.env.mcp.local
```

Should output: `CODERAG_NEO4J_PASSWORD=your_actual_password`

**2. Re-run MCP setup:**

```bash
cd /Users/kiel.mitchell/dotclaude
./scripts/setup-mcp.sh
```

**3. Verify MCP configuration:**

```bash
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

Should include:
```json
{
  "mcpServers": {
    "coderag": {
      "command": "/Users/kiel.mitchell/dotclaude/scripts/start-coderag.sh"
    }
  }
}
```

**4. Check Claude Code logs:**

On macOS:
```bash
tail -f ~/Library/Logs/Claude/mcp*.log
```

Look for CodeRAG startup errors.

**5. Restart Claude Code completely:**

```bash
# Force quit
killall Claude

# Relaunch
open -a Claude
```

Wait 10-15 seconds for MCP servers to initialize.

### Connection Errors

**Symptom:** "Could not connect to Neo4j" or "Connection refused".

**1. Verify Docker is running:**

```bash
docker info
```

If error: Start Docker Desktop or `sudo systemctl start docker` (Linux).

**2. Check Neo4j container is running:**

```bash
docker ps | grep coderag-neo4j
```

If not running:
```bash
docker compose -f /Users/kiel.mitchell/dotclaude/docker/coderag/docker-compose.yml up -d
```

**3. Check Neo4j is healthy:**

```bash
curl -f http://localhost:7474
```

Should return HTML response. If timeout: Neo4j still initializing (wait 30-60 seconds).

**4. Verify password matches:**

Password in `.env.mcp.local` must match password used to create container. If changed, recreate container:

```bash
docker compose -f /Users/kiel.mitchell/dotclaude/docker/coderag/docker-compose.yml down
docker compose -f /Users/kiel.mitchell/dotclaude/docker/coderag/docker-compose.yml up -d
```

### Scan Fails or Incomplete

**Symptom:** `scan_dir` returns errors or misses files.

**1. Check supported languages:**

CodeRAG supports: TypeScript, JavaScript, Java, Python

Other languages: May scan but with limited analysis.

**2. Verify directory path is absolute:**

```
scan_dir /absolute/path/to/project
```

Not: `~/path` or `./path` (expand these first).

**3. Check file permissions:**

```bash
ls -la /path/to/project
```

Ensure files are readable.

**4. Large codebases:**

Scanning 100K+ files may take 10-30 minutes. Check logs:

```bash
docker logs -f coderag-neo4j
```

### Memory Issues

**Symptom:** Neo4j crashes with "Out of memory" or Docker OOM killed.

**Increase Docker memory limit:**

Docker Desktop → Settings → Resources → Memory → Increase to 4GB+

**Or edit `docker-compose.yml`:**

```yaml
services:
  neo4j:
    deploy:
      resources:
        limits:
          memory: 4G
```

### Backup/Restore Fails

**Symptom:** `coderag-db-backup.sh` errors during backup or restore.

**1. Not logged into Docker Hub:**

```bash
docker login
```

**2. Image name format incorrect:**

Must be: `username/repository:tag` or `username/repository`

Example: `john/coderag-db:latest` ✓
Invalid: `coderag-db` ✗ (missing username)

**3. Permission denied on Docker Hub:**

Verify repository exists and you have push access:
https://hub.docker.com/repositories

**4. Large image size:**

Neo4j with large graphs can be 1GB+. Ensure sufficient:
- Disk space locally
- Docker Hub storage quota (free tier: unlimited public repos)

---

## Architecture

**System Overview:**

```
┌─────────────────────────────────────────────────────────────┐
│                        Claude Code                          │
│                    (AI Assistant Client)                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ MCP Protocol (JSON-RPC over stdio)
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              MCP Server Configuration                       │
│  ~/Library/Application Support/Claude/                      │
│       claude_desktop_config.json                            │
│                                                              │
│  Defines: "coderag" server command                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Executes
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│           scripts/start-coderag.sh                          │
│                                                              │
│  1. Loads .env.mcp.local environment variables             │
│  2. Ensures Neo4j Docker container is running              │
│  3. Waits for Neo4j health check (30s timeout)             │
│  4. Executes CodeRAG MCP server in STDIO mode              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Starts
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│         vendor/coderag/build/index.js                       │
│              (CodeRAG MCP Server)                           │
│                                                              │
│  - Exposes 23+ tools via MCP protocol                      │
│  - Handles code scanning, querying, analysis               │
│  - Connects to Neo4j for graph operations                  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Bolt Protocol (bolt://localhost:7687)
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Neo4j Docker Container                         │
│                  (coderag-neo4j)                            │
│                                                              │
│  Image: neo4j:5.12                                          │
│  Ports: 7474 (HTTP), 7687 (Bolt)                           │
│  Volumes: ~/neo4j-coderag/{data,logs,plugins}              │
│  Plugins: APOC (advanced graph procedures)                 │
└─────────────────────────────────────────────────────────────┘
```

**Data Flow:**

1. **User asks question** in Claude Code → "Find all classes in the project"
2. **Claude Code** analyzes request → Decides to use `find_nodes_by_type` tool
3. **MCP Protocol** sends tool call → JSON-RPC message to start-coderag.sh
4. **start-coderag.sh** ensures Neo4j running → Health check, then forwards request
5. **CodeRAG MCP Server** receives request → Translates to Cypher query
6. **Neo4j Database** executes query → Returns graph nodes/relationships
7. **CodeRAG** formats response → Returns to Claude Code via MCP
8. **Claude Code** presents results → Natural language summary to user

**Key Components:**

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Claude Code** | Electron app | AI assistant interface, user interaction |
| **MCP Protocol** | JSON-RPC over stdio | Communication between Claude Code and tools |
| **start-coderag.sh** | Bash script | Wrapper to manage Neo4j lifecycle and environment |
| **CodeRAG Server** | Node.js/TypeScript | MCP server implementation, tool logic |
| **Neo4j Database** | Graph database | Persistent storage of code knowledge graph |
| **Docker Compose** | Container orchestration | Neo4j deployment and configuration |

**Environment Files:**

- `.env.mcp` - Template with documentation (committed to git)
- `.env.mcp.local` - Your actual secrets (gitignored, never committed)
- `docker/coderag/docker-compose.yml` - Neo4j container configuration
- `claude_desktop_config.json` - MCP server registration

**Process Lifecycle:**

```
Claude Code starts
  → Reads claude_desktop_config.json
  → Spawns start-coderag.sh process
  → start-coderag.sh ensures Neo4j running
  → CodeRAG MCP server starts
  → Registers 23 tools with Claude Code
  → Ready for use

Claude Code exits
  → Terminates start-coderag.sh
  → CodeRAG MCP server stops
  → Neo4j container keeps running (restart: unless-stopped)
```

---

## Available Tools

CodeRAG exposes **23 powerful tools** via MCP. Examples of common workflows:

### Core CRUD Operations

- `add_node` - Create code entity (class, method, interface)
- `update_node` - Modify node properties
- `get_node` - Retrieve node by ID
- `delete_node` - Remove node and relationships
- `add_edge` - Create relationship (extends, implements, calls)
- `get_edge` - Retrieve relationship
- `delete_edge` - Remove relationship

### Search & Discovery

- `find_nodes_by_type` - Find all classes, methods, interfaces, etc.
- `search_nodes` - Text search across node properties
- `semantic_search` - Natural language code search (requires OpenAI)

### Relationship Analysis

- `find_dependencies` - Trace what a class/method depends on
- `find_dependents` - Find what depends on a class/method
- `get_call_graph` - Method invocation chains
- `find_inheritance_hierarchy` - Class inheritance trees

### Project Management

- `list_projects` - Show all scanned projects
- `get_project_summary` - Overview of project metrics
- `scan_dir` - Scan local directory
- `scan_github_repo` - Scan remote GitHub repository
- `scan_gitlab_repo` - Scan remote GitLab repository

### Quality & Metrics

- `calculate_metrics` - Compute CK metrics (WMC, CBO, RFC)
- `find_circular_dependencies` - Detect dependency cycles
- `identify_code_smells` - Find high coupling, god classes

### Annotation & Framework Analysis

- `find_nodes_by_annotation` - Find `@Controller`, `@Service`, etc.
- `get_framework_usage` - Identify Spring, React, Django usage
- `get_annotation_usage` - Count annotation occurrences

**Complete reference:** See `/Users/kiel.mitchell/dotclaude/vendor/coderag/docs/available-tools.md`

**Example conversation:**

```
User: "Scan my project at /path/to/my-app"
Claude: Uses scan_dir tool, returns summary

User: "Find all Spring controllers"
Claude: Uses find_nodes_by_annotation tool with "@Controller"

User: "What depends on the UserService class?"
Claude: Uses find_dependents tool, shows dependency graph

User: "Are there any circular dependencies?"
Claude: Uses find_circular_dependencies, reports cycles
```

---

## Next Steps

**After successful setup:**

1. **Scan your first project**
   ```
   In Claude Code: "Scan the project at /path/to/your/code"
   ```

2. **Explore the knowledge graph**
   ```
   "Show me all classes in this project"
   "Find classes with more than 10 methods"
   "What are the main dependencies?"
   ```

3. **Try semantic search** (if OpenAI configured)
   ```
   "Find code that handles authentication"
   "Show me error handling logic"
   ```

4. **Visualize in Neo4j Browser**
   - Open http://localhost:7474
   - Run Cypher queries to explore graph visually

5. **Set up multi-machine sync** (optional)
   ```bash
   # Backup on laptop
   ./scripts/coderag-db-backup.sh backup youruser/coderag-db:latest

   # Restore on desktop
   ./scripts/coderag-db-backup.sh restore youruser/coderag-db:latest
   ```

**Additional Resources:**

- CodeRAG documentation: `/Users/kiel.mitchell/dotclaude/vendor/coderag/docs/`
- Neo4j Cypher tutorial: https://neo4j.com/docs/cypher-manual/
- MCP Protocol docs: https://modelcontextprotocol.io/

**Get Help:**

- Check troubleshooting section above
- Review CodeRAG logs: `docker logs coderag-neo4j`
- Check Claude Code MCP logs: `~/Library/Logs/Claude/mcp*.log`
- CodeRAG issues: https://github.com/coderag/coderag/issues

---

**Congratulations!** CodeRAG is now integrated with Claude Code. Start exploring your codebase with AI-powered graph intelligence.

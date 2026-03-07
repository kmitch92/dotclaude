---
description: Generate comprehensive CDK infrastructure documentation — architecture diagrams, README, and service docs — for a CDK service or monorepo.
allowed-tools: Bash(*), Read(*), Write(*), Glob(*), Grep(*), TodoWrite
---

# CDK Documentation Generator

You are tasked with generating thorough, accurate infrastructure and service documentation for a CDK project. Work through each phase sequentially. Be rigorous and investigative — read actual source files, do not guess or hallucinate resource configurations.

---

## Phase 0 — Pre-flight Checks

### 0.1 Locate the CDK entry file

Search the current directory for a CDK entry file. The canonical name is `cdk.ts`, but also check `bin/cdk.ts`, `bin/*.ts`, and any TypeScript file that calls `new App()` or `app.synth()`.

```bash
find . -maxdepth 3 \( -name "cdk.ts" -o -name "*.ts" \) \
  ! -path "*/node_modules/*" ! -path "*/.git/*" \
  | xargs grep -l "new App\(\)\|app\.synth()" 2>/dev/null | head -10
```

**If no CDK entry file is found:** Stop immediately and output:

> ❌ No CDK entry file found in the current directory. Run `/document` from the root of a CDK project or monorepo.

Do not proceed further.

### 0.2 Detect project scope (monorepo vs single service)

Determine whether you are at a **monorepo root** or a **single service**:

- **Monorepo signals:** multiple `package.json` files in subdirectories, a root `package.json` with `workspaces`, directories with their own `cdk.ts` or `lib/` stacks, a `packages/` or `services/` folder structure, or a `lerna.json` / `nx.json` / `turbo.json` at the root.
- **Single service signals:** a single `cdk.ts` + `lib/` in the current directory, a single `package.json` with CDK dependencies directly.

```bash
# Check for monorepo markers
ls package.json lerna.json nx.json turbo.json pnpm-workspace.yaml 2>/dev/null
find . -maxdepth 3 -name "package.json" ! -path "*/node_modules/*" | head -20
find . -maxdepth 3 -name "cdk.ts" ! -path "*/node_modules/*" | head -10
```

Set your working context accordingly. **If at a monorepo root**, you will produce `README.md` (monorepo overview) and `architecture.md` (monorepo-level infra). You will *read* service-level READMEs and docs that already exist but will not re-document each service individually in isolation — your output covers the system as a whole. `service.md` is produced at the **service level**, so skip it if you are at a monorepo root unless you are clearly inside one specific service.

---

## Phase 1 — Deep Code Investigation

Before generating any documentation, do a thorough investigation of the codebase. Read the actual source, do not assume or invent.

### 1.1 Read existing documentation
```bash
find . -maxdepth 4 \( -name "README.md" -o -name "ARCHITECTURE.md" -o -name "*.md" \) \
  ! -path "*/node_modules/*" ! -path "*/.git/*" | head -20
```
Read each discovered markdown file. Note existing context, conventions, and any documented design decisions.

### 1.2 Understand the CDK stack structure
Read the CDK entry file and all stack/construct files:

```bash
find . -maxdepth 5 -path "*/lib/*.ts" ! -path "*/node_modules/*" | head -30
find . -maxdepth 5 -path "*/stacks/*.ts" ! -path "*/node_modules/*" | head -20
find . -maxdepth 5 -path "*/constructs/*.ts" ! -path "*/node_modules/*" | head -20
```

Read each of these files. For every stack, identify:
- Stack name (as passed to `new Stack(app, '<name>', ...)`)
- All AWS resources defined (Lambda, DynamoDB, SQS, SNS, Step Functions, API Gateway, S3, Bedrock, EventBridge, etc.)
- Environment variables, IAM roles, and cross-stack dependencies (`Fn.importValue`, `ssm.StringParameter`, cross-stack refs)
- VPC/networking configuration if present

### 1.3 Understand Lambda functions in depth
```bash
find . -maxdepth 6 \( -path "*/functions/*" -o -path "*/handlers/*" -o -path "*/lambdas/*" \) \
  -name "*.ts" ! -path "*/node_modules/*" | head -40
find . -maxdepth 6 -name "handler.ts" ! -path "*/node_modules/*" | head -20
```

For each Lambda handler, read the file and understand:
- Trigger/event source (SQS, SNS, EventBridge, API GW, Step Functions, S3, DynamoDB streams, etc.)
- What it does (business logic summary)
- External services or AWS services it calls
- Input/output contract (event shape, return shape)
- Error handling patterns

### 1.4 Understand Step Functions workflows
```bash
grep -r "StateMachine\|sfn\.\|aws_stepfunctions" --include="*.ts" -l \
  ! -path "*/node_modules/*" 2>/dev/null | head -10
```
If Step Functions are used, read those definitions and trace the state machine flow.

### 1.5 Read configuration and environment files
```bash
find . -maxdepth 3 \( -name "*.env*" -o -name "config.ts" -o -name "constants.ts" -o -name "environment.ts" \) \
  ! -path "*/node_modules/*" | head -20
cat package.json
```

### 1.6 Check for inter-service communication patterns
```bash
grep -r "EventBus\|EventBridge\|SQSEvent\|SNSEvent\|DynamoDBStreamEvent\|S3Event" \
  --include="*.ts" -l ! -path "*/node_modules/*" 2>/dev/null | head -20
grep -r "import\|require" --include="*.ts" -rn \
  ! -path "*/node_modules/*" 2>/dev/null | grep "\.\./\.\." | head -20
```

---

## Phase 2 — Generate the cdk-dia Diagram

### 2.1 Check and install prerequisites

**Check Graphviz:**
```bash
which dot && dot -V 2>&1 || echo "NOT_FOUND"
```

If `dot` is not found, attempt installation:
```bash
# Try common package managers
if command -v brew &>/dev/null; then brew install graphviz
elif command -v apt-get &>/dev/null; then sudo apt-get install -y graphviz
elif command -v yum &>/dev/null; then sudo yum install -y graphviz
else echo "CANNOT_INSTALL_GRAPHVIZ"
fi
```

If Graphviz cannot be installed, note this and continue — you will produce Mermaid diagrams manually in Phase 3 as the primary diagram source.

**Check cdk-dia:**
```bash
# Check local install
npx cdk-dia --version 2>/dev/null || echo "NOT_INSTALLED_LOCAL"
# Check global install
cdk-dia --version 2>/dev/null || echo "NOT_INSTALLED_GLOBAL"
```

If not installed locally, install it:
```bash
npm install --save-dev cdk-dia 2>&1 | tail -5
```

### 2.2 Build and synthesise the CDK app

cdk-dia requires a synthesised CDK output (`cdk.out/`). Ensure the app is compiled and synthesised:

```bash
# Build first (TypeScript must be compiled before synth)
npm run build 2>&1 | tail -20
# or if there's a specific build script:
# npx tsc --noEmit 2>&1 | tail -10
```

```bash
# Check if cdk.out already exists and is recent (less than 10 minutes old)
if [ -d "cdk.out" ]; then
  find cdk.out -maxdepth 0 -newer package.json 2>/dev/null && echo "SYNTH_RECENT" || echo "SYNTH_STALE"
else
  echo "NO_SYNTH"
fi
```

If `cdk.out` is missing or stale:
```bash
npx cdk synth --quiet 2>&1 | tail -30
```

If `cdk synth` fails, try:
```bash
# Some projects require explicit app path
npx cdk synth --app "npx ts-node cdk.ts" --quiet 2>&1 | tail -30
# or
npx cdk synth --app "node dist/cdk.js" --quiet 2>&1 | tail -20
```

### 2.3 Discover available stacks

```bash
# Read the CDK tree to find actual stack names
cat cdk.out/tree.json 2>/dev/null | python3 -c "
import json, sys
tree = json.load(sys.stdin)
def find_stacks(node, path=''):
    if node.get('constructInfo', {}).get('fqn', '').endswith('Stack'):
        print(path or node.get('id'))
    for child_id, child in node.get('children', {}).items():
        find_stacks(child, child_id)
find_stacks(tree.get('tree', {}))
" 2>/dev/null || ls cdk.out/*.template.json 2>/dev/null | sed 's|cdk.out/||;s|\.template\.json||'
```

Note the stack names — you will use them to pass `--stacks` to cdk-dia if needed.

### 2.4 Run cdk-dia

```bash
# Run with all stacks (default)
npx cdk-dia 2>&1
```

If this fails with a "no stacks found" or "unrecognised stack" error, try with explicit stacks:
```bash
# Replace STACK_NAMES with the names discovered in step 2.3
npx cdk-dia --stacks STACK_NAME_1 STACK_NAME_2 2>&1
# or using --include
npx cdk-dia --include STACK_NAME 2>&1
```

If cdk-dia fails entirely (e.g. Graphviz not available, build issue), note the error and proceed — you will produce Mermaid-based diagrams in Phase 3 as the primary visual artefacts.

```bash
# Check if diagram was generated
ls -lh diagram.png diagram.dot 2>/dev/null || echo "NO_DIAGRAM_GENERATED"
```

---

## Phase 3 — Build Mermaid Diagrams

Regardless of whether cdk-dia succeeded, produce Mermaid diagrams to supplement or replace it. These will be embedded in the markdown documents. Mermaid diagrams should be **accurate** — derived from your Phase 1 investigation, not invented.

### 3.1 Infrastructure Overview Diagram (flowchart)

Produce a high-level Mermaid `flowchart LR` or `flowchart TD` showing the AWS resources and their relationships:
- Group resources by stack using `subgraph`
- Show data flow arrows: event sources → Lambda → targets
- Include DynamoDB tables, SQS queues, SNS topics, S3 buckets, Step Functions, API Gateway, EventBridge buses
- Label arrows with the event/trigger type
- Do not include every IAM role or low-level CDK boilerplate — show meaningful architectural relationships

Example shape:
```
flowchart LR
  subgraph IngestStack
    apigw[API Gateway] --> ingestFn[Lambda: ingest]
    ingestFn --> queue[SQS: ingest-queue]
  end
  subgraph ProcessStack
    queue --> processFn[Lambda: process]
    processFn --> table[(DynamoDB: products)]
    processFn --> bus[EventBridge: events]
  end
```

### 3.2 Logical Flow Diagrams

For each significant workflow or process (e.g. a translation pipeline, an order flow, a batch job), produce a `sequenceDiagram` or `flowchart` showing the step-by-step logical flow through the system. Derive these from your Lambda handler investigations in Phase 1.3 and Step Functions in Phase 1.4.

If Step Functions are used, produce a dedicated flowchart of the state machine.

### 3.3 Data Flow Diagram (if applicable)

If there are meaningful data transformations (e.g. product enrichment, AI inference pipelines, ETL flows), produce a diagram showing data entering, being transformed, and leaving the system.

---

## Phase 4 — Write the Documentation

Now produce the documentation files. Write them directly to the filesystem. Be specific and accurate — reference actual resource names, function names, table names, queue names as found in the code.

### 4.1 `architecture.md` — Infrastructure & Architecture Reference

This document targets engineers who need to understand the infrastructure in depth.

Write this file as `./architecture.md` (at the current working directory level).

Structure:
```markdown
# Architecture — [Project/Service Name]

> One-sentence description of what this system does.

## Infrastructure Overview

[Embed the cdk-dia diagram if generated: ![CDK Infrastructure](./diagram.png)]
[Always embed the Mermaid infrastructure overview diagram]

Brief prose description of the overall architecture pattern (e.g. event-driven, serverless, pipeline-based).

## Stacks

For each CDK stack:
### `StackName`
- **Purpose:** What this stack provisions
- **Key Resources:** Bulleted list of AWS resources with their logical names
- **Dependencies:** Other stacks or external resources this stack depends on

## AWS Resources Inventory

Table or bulleted list of all significant resources:
| Resource | Type | Stack | Purpose |
|---|---|---|---|
| ... | Lambda | ... | ... |

## Data Flows & Event Routing

[Embed logical flow diagrams from Phase 3.2]

Prose description of how data and events move through the system.

## Inter-Service / Inter-Stack Dependencies

Describe how stacks share data — SSM parameters, CloudFormation exports, shared event buses, etc.

## IAM & Security Model

Describe the principal IAM roles, least-privilege patterns, and any notable security boundaries.

## Environment Configuration

List environment variables and config parameters, grouped by stack or Lambda.

## Operational Notes

Observability (CloudWatch dashboards, alarms, X-Ray tracing if used), deployment commands, known limitations.
```

### 4.2 `README.md` — General Introduction / Technical Overview

**At monorepo level:** Write a comprehensive `README.md` at the current directory level covering the whole system.

**At single-service level:** Write a `README.md` if one does not already exist, or augment an existing one if it is sparse (fewer than 30 lines).

Structure:
```markdown
# [Project Name]

> One-sentence value proposition.

## Overview

2–3 paragraph description of what the system is, what problem it solves, and how it works at a high level.

## Services / Packages

[Monorepo only] Table or list of services/packages with a one-line description each, linking to their directories.

## Tech Stack

Bulleted list: language, CDK version, key AWS services used, key npm dependencies.

## Getting Started

### Prerequisites
- Node.js version
- AWS CLI configured
- CDK bootstrapped (`cdk bootstrap`)

### Installation
```bash
npm install
```

### Deployment
```bash
npm run build
cdk synth
cdk deploy --all
```

## Development

How to run locally, test, lint.

## Repository Structure

Tree or description of top-level directory structure.

## Further Reading

Links to architecture.md, service.md, any ADRs.
```

### 4.3 `service.md` — Service-Level Technical Overview

**Produce this file only when operating at a single-service level** (or when clearly inside one specific service within a monorepo).

Write `./service.md` as the technical reference for engineers working on this specific service.

Structure:
```markdown
# [Service Name] — Technical Reference

## Purpose

What this service does within the wider system.

## Architecture

[Embed infrastructure diagram scoped to this service]

## Lambda Functions

For each Lambda function:
### `functionName`
- **Trigger:** What invokes it (SQS, EventBridge rule name, API route, etc.)
- **Responsibility:** What it does
- **Inputs:** Event schema summary
- **Outputs / Side Effects:** What it writes, publishes, or returns
- **Key Dependencies:** DynamoDB tables, external APIs, downstream queues/topics it interacts with

## Data Models

Key DynamoDB table schemas, S3 object shapes, or SQS message formats, as found in the code.

## Step Functions (if applicable)

[Embed state machine diagram]

Description of each state and its purpose.

## Configuration

Environment variables and their meaning.

## Error Handling & Retry Strategy

DLQs, retry configurations, error states.

## Deployment

Service-specific deployment notes (e.g. whether deploying this service has dependencies on other stacks being deployed first).

## Runbook

Common operational tasks: how to re-drive a DLQ, how to trigger a manual run, how to check logs.
```

---

## Phase 5 — Final Checks

```bash
ls -lh architecture.md README.md service.md 2>/dev/null
```

Review each generated file:
- Confirm all resource names are **real names from the code**, not placeholders
- Confirm all Mermaid diagrams are syntactically valid (no unclosed brackets, valid node IDs without spaces)
- Confirm links between documents are correct
- If `diagram.png` was generated by cdk-dia, confirm the reference in `architecture.md` is correct

Report a brief summary to the user:
```
✅ Documentation generated:
  - architecture.md  — infrastructure reference with diagrams
  - README.md        — project overview
  - service.md       — service technical reference (if applicable)

📊 Diagrams:
  - cdk-dia diagram: [generated ✅ | failed ❌ — reason]
  - Mermaid diagrams: embedded in architecture.md and service.md

⚠️  Notes: [any warnings, e.g. cdk synth required manual intervention, or a stack couldn't be diagrammed]
```
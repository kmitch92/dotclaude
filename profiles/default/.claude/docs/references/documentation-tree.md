# Documentation Directory Structure

**Complete documentation repository structure (35 files across 4 categories):**

```
~/.claude/docs/
├── workflows/           (4 files - Process flows)
│   ├── tdd-cycle.md
│   ├── collaboration-patterns.md
│   ├── collaboration-workflows.md
│   └── code-review-process.md
├── patterns/            (28 files - Domain-specific patterns)
│   ├── backend/         (4 files: api-design, database-design, database-integration, lambda-patterns)
│   ├── react/           (8 files: component-composition, component-state, hooks-state, hooks-effects, hooks-performance, testing-patterns, testing-queries, testing-mocks)
│   ├── typescript/      (5 files: schemas, strict-mode, type-vs-interface, branded-types, effect-ts)
│   ├── security/        (6 files: auth-jwt, auth-oauth, auth-sessions, owasp-injection, owasp-auth, owasp-crypto)
│   ├── refactoring/     (3 files: common-patterns, dry-semantics, when-to-refactor)
│   └── performance/     (2 files: database-optimization, react-optimization)
├── references/          (8 files - Quick lookups)
│   ├── standards-checklist.md
│   ├── code-style.md
│   ├── agent-quick-ref.md
│   ├── working-with-claude.md
│   ├── http-status-codes.md
│   ├── severity-levels.md
│   ├── indexing-strategies.md
│   └── normalization.md
└── examples/            (5 files - Walkthroughs)
    ├── tdd-complete-cycle.md
    ├── schema-composition.md
    ├── factory-patterns.md
    ├── refactoring-journey.md
    └── git-commands-cheatsheet.md
```

All agents have access to these docs via the Read tool.

## How to Reference Documentation

**Pattern**: `@~/.claude/docs/[category]/[filename].md`

**Example Commands to Access Documentation:**

```bash
# Read complete TDD process
Read file: ~/.claude/docs/workflows/tdd-cycle.md

# Read agent collaboration patterns
Read file: ~/.claude/docs/workflows/collaboration-patterns.md

# Read agent collaboration workflows
Read file: ~/.claude/docs/workflows/collaboration-workflows.md

# Read Zod schema patterns
Read file: ~/.claude/docs/patterns/typescript/schemas.md

# Read backend API design guide
Read file: ~/.claude/docs/patterns/backend/api-design.md

# Read React component composition patterns
Read file: ~/.claude/docs/patterns/react/component-composition.md

# Read React component state patterns
Read file: ~/.claude/docs/patterns/react/component-state.md

# Read React hooks patterns
Read file: ~/.claude/docs/patterns/react/hooks-state.md

# Read React testing patterns
Read file: ~/.claude/docs/patterns/react/testing-patterns.md

# Read OWASP injection prevention
Read file: ~/.claude/docs/patterns/security/owasp-injection.md

# Read OWASP authentication vulnerabilities
Read file: ~/.claude/docs/patterns/security/owasp-auth.md

# Read code style standards
Read file: ~/.claude/docs/references/code-style.md

# Read factory pattern examples
Read file: ~/.claude/docs/examples/factory-patterns.md

# Read git commands cheatsheet
Read file: ~/.claude/docs/examples/git-commands-cheatsheet.md
```

## Categories Quick Reference

- **workflows/** (4 files) - TDD cycle, collaboration patterns, collaboration workflows, code review process
- **patterns/backend/** (4 files) - API design, database design, database integration, Lambda patterns
- **patterns/react/** (8 files) - Component composition, component state, hooks (state, effects, performance), testing (patterns, queries, mocks)
- **patterns/typescript/** (5 files) - Schemas, strict mode, type vs interface, branded types, Effect-TS
- **patterns/security/** (6 files) - Authentication (JWT, OAuth, sessions), OWASP (injection, auth, crypto)
- **patterns/refactoring/** (3 files) - Common patterns, DRY semantics, when to refactor
- **patterns/performance/** (2 files) - Database optimization, React optimization
- **references/** (8 files) - Standards checklist, code style, HTTP status codes, indexing strategies, normalization, severity levels, agent quick ref, working with Claude
- **examples/** (5 files) - TDD complete cycle, schema composition, factory patterns, refactoring journey, git commands cheatsheet

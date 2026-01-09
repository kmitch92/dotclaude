# Standards & Quality Gates Checklist

## Pre-Commit Checklist

### TDD Compliance
- [ ] Every production code line written in response to failing test
- [ ] No code exists without corresponding test
- [ ] Followed Red-Green-Refactor cycle
- [ ] Tests written BEFORE implementation

### TypeScript Strict Mode
- [ ] TypeScript strict mode enabled
- [ ] No `any` types (use `unknown` if type truly unknown)
- [ ] No type assertions (`as Type`) without justification
- [ ] All type errors resolved

### Schema-First Development
- [ ] Zod schemas defined at trust boundaries
- [ ] Types derived from schemas (not defined separately)
- [ ] Tests import real schemas (not redefined)
- [ ] Schema validation at entry points

### Immutability
- [ ] No data mutation anywhere
- [ ] Arrays: Use `.map()`, `.filter()`, `.reduce()`, spread operator
- [ ] Objects: Use spread operator, object rest
- [ ] No `.push()`, `.pop()`, `.shift()`, `.unshift()`, `.splice()`
- [ ] No direct property assignment

### Pure Functions
- [ ] Functions return same output for same input
- [ ] No side effects in business logic
- [ ] Side effects isolated and explicit
- [ ] No global state modifications

### Code Quality
- [ ] No nested conditionals (use early returns)
- [ ] No comments (code is self-documenting)
- [ ] Prefer `type` over `interface`
- [ ] Function/variable names describe purpose
- [ ] Small, focused functions (single responsibility)

### Testing Quality
- [ ] 100% behavior coverage (not line coverage goal)
- [ ] Tests verify behavior through public APIs
- [ ] No testing implementation details
- [ ] No 1:1 mapping test files to implementation
- [ ] Tests describe user-observable outcomes

## Pre-Merge Checklist

### Code Review
- [ ] Quality & Refactoring Specialist review completed
- [ ] Test Writer verified coverage
- [ ] TypeScript Connoisseur reviewed types
- [ ] Production Readiness Specialist reviewed (if auth/data/permissions/performance)
- [ ] All feedback addressed

### Testing
- [ ] All tests passing
- [ ] No skipped tests
- [ ] Edge cases covered
- [ ] Error paths tested
- [ ] Integration tests passing (if applicable)

### Documentation
- [ ] Project CLAUDE.md updated with learnings
- [ ] API contracts documented (if new endpoints)
- [ ] Breaking changes documented
- [ ] Migration guide provided (if breaking changes)

### Git Hygiene
- [ ] Commits follow conventional commits format
- [ ] Commit messages explain "why" not "what"
- [ ] No WIP or "fix" commits (squashed)
- [ ] Branch follows naming conventions

## Pre-Production Checklist

### Security
- [ ] Production Readiness Specialist security audit completed
- [ ] No secrets in code
- [ ] Authentication/authorization tested
- [ ] Input validation at all boundaries
- [ ] SQL injection prevention verified
- [ ] XSS prevention verified
- [ ] CSRF protection verified (if applicable)

### Performance
- [ ] Production Readiness Specialist performance review completed
- [ ] No N+1 queries
- [ ] Database indexes optimized
- [ ] Response times measured
- [ ] Load testing completed (if critical path)
- [ ] Memory leaks checked

### Reliability
- [ ] Error handling comprehensive
- [ ] Graceful degradation implemented
- [ ] Retry logic for transient failures
- [ ] Circuit breakers (if external dependencies)
- [ ] Monitoring/logging in place

### Infrastructure
- [ ] Backend TypeScript Developer reviewed infrastructure
- [ ] IAM permissions principle of least privilege
- [ ] Resources tagged appropriately
- [ ] Cost optimization reviewed
- [ ] Backup/recovery tested

## Red Flags (Zero Tolerance)

### Code Quality
❌ Production code without tests
❌ `any` types in TypeScript
❌ Data mutation
❌ Nested conditionals (>2 levels)
❌ Functions >50 lines
❌ Commented-out code
❌ Console.log in production code

### Security
❌ Hardcoded secrets
❌ Unsanitized user input
❌ Missing authentication checks
❌ Missing authorization checks
❌ SQL string concatenation
❌ innerHTML with user data

### Testing
❌ Tests testing implementation details
❌ Skipped tests
❌ Tests dependent on execution order
❌ Tests with hardcoded wait times
❌ Flaky tests

### Architecture
❌ Tight coupling between modules
❌ God objects/functions
❌ Circular dependencies
❌ Business logic in UI components
❌ Direct database access from UI

## Quick Validation Commands

```bash
# TypeScript check
npm run type-check

# Run all tests
npm test

# Coverage report
npm run test:coverage

# Lint check
npm run lint

# Format check
npm run format:check

# Build check
npm run build

# Security audit
npm audit

# Git status clean
git status

# No uncommitted changes
git diff --exit-code
```

## Delegation Checklist

### Main Agent Pre-Flight
- [ ] Requirements understood (or clarification asked)
- [ ] Appropriate agents identified
- [ ] Parallel vs sequential determined
- [ ] Task dependencies mapped
- [ ] No direct implementation by main agent

### Agent Assignment Validation
- [ ] Every task assigned to specific agent
- [ ] No generic "implement X" statements
- [ ] Execution model specified (parallel/sequential)
- [ ] Dependencies explicitly stated
- [ ] Return expectations clear

## Common Anti-Patterns to Avoid

### Code
- Magic numbers (use named constants)
- Boolean parameters (use options object)
- Deep nesting (max 2 levels)
- Large functions (max 50 lines)
- Implicit returns (be explicit)

### Testing
- Testing private methods
- Asserting on implementation details
- Shared test state
- Test interdependencies
- Unclear test names

### Architecture
- Leaky abstractions
- Premature optimization
- God objects
- Anemic domain models
- Tight coupling

## When to Stop and Ask

**Stop immediately if:**
- Requirements ambiguous or conflicting
- Multiple valid approaches with different tradeoffs
- Breaking changes required
- User preference needed
- Facing development impasse
- Core config files need modification
- Existing functionality might break

**Summarize and wait for direction.**

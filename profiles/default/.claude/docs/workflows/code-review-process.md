# Code Review Process

Quality verified through specialized perspectives in parallel, synthesized into prioritized feedback.

## Review Types

### Standard Code Review

**Scope:** Code quality, patterns, maintainability

**Agents (max 3 parallel):**
- Quality & Refactoring
- Test Writer
- TypeScript Connoisseur

**Use when:** PR review, refactoring assessment, general health check

### Security/Performance Review

**Scope:** Auth, PII, payments, user input, API endpoints, data processing

**Agents (sequential batches, max 3 parallel):**
- **Batch 1**: Quality & Refactoring + TypeScript Connoisseur + Test Writer
- **Batch 2**: Production Readiness

**Use when:** Auth flows, payment processing, data handling, API endpoints with SLA

### Pre-Production Review

**Scope:** Comprehensive readiness

**Agents (sequential batches):**
- **Batch 1**: Quality & Refactoring + TypeScript Connoisseur + Test Writer
- **Batch 2**: Production Readiness

**Use when:** Before production deployment, major feature release, compliance review

## Review Process

### Step 1: Determine Scope

**Decision criteria:**
```
Auth/authorization logic? → Include Production Readiness
PII/credentials/payments? → Include Production Readiness
Processes user input? → Include Production Readiness
API endpoint with SLA? → Include Production Readiness
Database operations? → Include Production Readiness
Otherwise → Standard review
```

### Step 2: Invoke Agents (Batches)

**Standard Review (3 agents in parallel):**
```
[SINGLE message with THREE Task calls]
- quality-refactoring-specialist: Code quality
- TypeScript Connoisseur: Type safety
- Test Writer: Coverage verification
```

**Security/Performance Review (4 agents - batched):**
```
BATCH 1 [SINGLE message, THREE Task calls]:
- quality-refactoring-specialist
- TypeScript Connoisseur
- Test Writer

[Review Batch 1 findings]

BATCH 2 [SINGLE message, ONE Task call]:
- production-readiness-specialist
```

### Step 3: Synthesize Feedback

Main Agent groups by severity, identifies dependencies, removes duplicates.

**Severity Classification:**

🔴 **CRITICAL** - Must fix before merge
- Security vulnerabilities
- Performance causing user problems
- Data loss risks
- Breaking changes without migration
- Broken functionality

⚠️ **HIGH VALUE** - Fix now
- Moderate performance issues
- Maintainability problems
- Missing coverage for critical paths
- Type safety risks

💡 **NICE TO HAVE** - Consider
- Minor improvements
- Additional edge cases
- Type narrowing
- Documentation

✅ **SKIP** - Not worth addressing
- Bikeshedding
- Premature optimization
- Over-engineering

### Step 4: Present Feedback

**Format:**
```
Code Review: [Feature/PR Name]

🔴 CRITICAL:
1. [Agent] Issue description
   - Impact: What could happen
   - Location: file:line
   - Fix: Specific action

⚠️ HIGH VALUE:
2. [Agent] Issue description
   - Impact: Effect on maintainability/performance
   - Location: file:line
   - Fix: Specific action

💡 NICE TO HAVE:
3. [Agent] Suggestion
   - Benefit: Why consider
   - Note: Context or conditions

✅ SKIP:
4. [Agent] Suggestion not recommended
   - Reason: Why skipping
```

## Agent Responsibilities

### quality-refactoring-specialist

**Reviews for:**
- Immutability violations
- Nested conditionals
- Functional patterns
- Naming clarity
- Anti-patterns
- Refactoring opportunities

### Test Writer

**Reviews for:**
- Coverage gaps
- Implementation detail testing
- Schema usage (real vs redefined)
- Test organization
- Missing edge cases

### TypeScript Connoisseur

**Reviews for:**
- Strict mode compliance
- `any` types
- Type assertions
- Schema-first violations
- Type narrowing opportunities

### production-readiness-specialist

**Reviews for:**
- **Security**: Input validation, injection, auth/authz, PII, secrets
- **Performance**: Database queries, algorithms, memory, network, rendering

## Synthesis Guidelines

### Prioritization Framework

**Critical Assignment:**
- Security vulnerability (any)
- Performance causing user issues (>500ms delay)
- Data loss risk
- Production outage risk
- Broken core functionality

**High Value Assignment:**
- Moderate performance (>100ms delay)
- Code quality preventing changes
- Test gaps for critical paths
- Type safety risking runtime errors

**Nice to Have Assignment:**
- Minor optimization (<50ms)
- Unlikely edge cases
- Type narrowing improving DX
- Clear style improvements

**Skip Assignment:**
- Subjective preferences
- Premature optimization
- Over-engineering
- Clarity-reducing suggestions

### Dependency Identification

**Common dependencies:**
1. Security fixes first (always)
2. Test coverage before refactoring
3. Type safety before optimization
4. Fix broken before adding features

### Avoiding Duplication

Multiple agents may identify same issue from different angles.

**Synthesize:**
```
Immutability violation in cart reducer (src/cart/reducer.ts:23)
- Quality & Refactoring: Unpredictable state updates
- TypeScript: Type system misses errors
Fix: Use spread operator for new array
```

## Workflows

### Standard Review

```
USER: "Review payment processing PR"

MAIN AGENT:
1. Analyze scope → Security-sensitive
2. Invoke Batch 1 (3 parallel):
   - quality-refactoring-specialist
   - TypeScript Connoisseur
   - Test Writer
3. Review Batch 1 findings
4. Invoke Batch 2:
   - production-readiness-specialist
5. Synthesize all findings
6. Present prioritized feedback
```

### Pre-Production Review

```
USER: "Pre-production review for checkout"

MAIN AGENT:
1. Analyze scope → Complete flow, security, performance
2. Invoke Batch 1 (3 parallel):
   - quality-refactoring-specialist
   - TypeScript Connoisseur
   - Test Writer
3. Review Batch 1
4. Invoke Batch 2:
   - production-readiness-specialist
5. Synthesize with production focus
6. Present readiness assessment:
   - Ready (no critical)
   - Blocked (critical must fix)
   - Ready with caveats (critical fixed, high tracked)
```

### Iterative Review

```
USER: "Fixed critical issues, re-review"

MAIN AGENT:
1. Identify which agents reviewed affected code
2. Invoke ONLY affected agents (parallel if ≤3)
3. Verify fixes
4. Present updated status:
   - ✅ Fixed: [list]
   - 🔴 Remaining: [list]
   - ⚠️ New findings: [list]
```

## Quality Gates

### Pre-Merge Gate

- [ ] 🔴 Zero critical issues
- [ ] ⚠️ High value issues addressed or tracked with justification
- [ ] Test Writer: 100% behavior coverage, no implementation tests
- [ ] All tests passing
- [ ] TypeScript: No errors, strict mode compliant

### Pre-Production Gate

- [ ] All Pre-Merge criteria met
- [ ] Production Readiness approval for security/performance-sensitive features
- [ ] quality-refactoring-specialist: No critical maintainability issues
- [ ] documentation-specialist: Learnings captured in project CLAUDE.md

## Common Scenarios

### Critical Security Issue

**Action:**
1. Mark 🔴 CRITICAL
2. Block merge/deploy
3. Re-invoke Production Readiness after fix
4. Test Writer adds security tests

### All Agents Approve

```
Code Review: ✅ APPROVED

All quality gates passed:
- Code quality: Clean, maintainable
- Test coverage: 100% behaviors
- Type safety: Strict compliant
- Security & Performance: No issues

Ready to merge.
```

## Summary

Multi-agent parallel process:

1. Main Agent determines review type
2. Agents review in batches (max 3 parallel)
3. Main Agent synthesizes prioritized feedback
4. Severity-based focus on high-impact issues
5. Quality gates enforce standards before merge/deploy

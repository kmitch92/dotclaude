---
description: Identify unused exports (cruft) and report with rationale
allowed-tools: Bash(rg:*), Bash(grep:*), Bash(find:*), Read, Grep, Glob
model: sonnet
---

Analyze the codebase for unused exports (cruft) and generate a comprehensive report. This is a READ-ONLY analysis - do NOT delete any code.

## Process

### Step 1: Discover Exports

Use Grep to find all export statements in TypeScript/JavaScript files:

```
Pattern: export\s+(const|function|class|type|interface|default|{|\*)
Include: *.ts, *.tsx, *.js, *.jsx files
Output mode: content with line numbers
```

For each export found, parse and extract:
- File path
- Line number
- Export type (const, function, class, type, interface, default, named, re-export)
- Exported name(s)

**Handle these export formats:**
- `export const NAME = ...`
- `export function NAME() { ... }`
- `export class NAME { ... }`
- `export type NAME = ...`
- `export interface NAME { ... }`
- `export default NAME`
- `export { NAME1, NAME2, NAME3 }`
- `export { NAME as ALIAS }`
- `export * from './module'`
- `export * as namespace from './module'`
- `export type { Type1, Type2 }`

### Step 2: Check for Imports

For each exported item, search the codebase (EXCLUDING the file where it's exported) for import usage:

**Use these regex patterns with Grep (multiline mode if needed):**

1. **Named imports**: `import\s*\{[^}]*\bNAME\b[^}]*\}\s*from`
2. **Default imports**: `import\s+NAME\s+from`
3. **Namespace imports**: `import\s*\*\s*as\s*\w+\s*from.*['"]\.\/.*NAME`
4. **Aliased imports**: `import\s*\{[^}]*\bNAME\b\s+as\s+\w+[^}]*\}\s*from`
5. **Type imports**: `import\s+type\s*\{[^}]*\bNAME\b[^}]*\}\s*from`
6. **Dynamic imports**: `import\s*\(\s*['"].*NAME.*['"]\)`
7. **Require**: `require\s*\(\s*['"].*NAME.*['"]\)`

**Important**: Search entire codebase EXCEPT the source file itself. Exclude node_modules, dist, build directories.

### Step 3: Evaluate Cruft Status

For each export with NO imports found, determine confidence level:

**NOT CRUFT (skip reporting):**
- Entry point files: index.ts, main.ts, app.ts, _app.tsx, _document.tsx
- Config file exports: vite.config.ts, tailwind.config.ts, jest.config.ts, etc.
- API routes/handlers: pages/, app/api/, routes/ directories (Next.js, Express, etc.)
- Test setup files: setupTests.ts, vitest.setup.ts, jest.setup.ts
- Re-exports in barrel files: `export * from './module'`
- Files in public API directories: lib/, sdk/, public/
- Exports with JSDoc tags: @public, @exported, @api
- Next.js special exports: getServerSideProps, getStaticProps, getInitialProps, config, runtime
- Package entry points: files referenced in package.json "main", "exports", "types"

**HIGH CONFIDENCE (definitely cruft):**
- No imports found anywhere in codebase
- Not in any excluded categories above
- Export is a concrete implementation (const, function, class)
- File is not an entry point or config file

**MEDIUM CONFIDENCE (likely cruft):**
- No imports found
- Type-only export (type, interface) that might be used indirectly
- Export in utility/helper file that could be dynamic import
- File name suggests it might be entry point but isn't definitively one

**LOW CONFIDENCE (uncertain):**
- Possible dynamic import patterns detected (string concatenation in imports)
- File in directory that might contain runtime-discovered exports
- Export name matches pattern that suggests framework usage (handle*, on*, use*)

### Step 4: Generate Report

Create structured report grouped by confidence level and directory:

```
# Unused Exports Report (cruftsoft)

## Summary
- Total exports analyzed: N
- HIGH confidence cruft: N
- MEDIUM confidence cruft: N
- LOW confidence cruft: N

## HIGH Confidence (Definitely Unused)

### src/utils/
[HIGH] src/utils/deprecated.ts:15 - calculateLegacy
  Type: const
  Reason: No imports found in codebase

[HIGH] src/utils/old-helpers.ts:8 - formatOldWay
  Type: function
  Reason: No imports found in codebase

### src/components/
[HIGH] src/components/UnusedButton.tsx:5 - UnusedButton
  Type: const (component)
  Reason: No imports found in codebase

## MEDIUM Confidence (Likely Unused)

### src/types/
[MEDIUM] src/types/legacy.ts:12 - OldUserType
  Type: interface
  Reason: No imports found, but type-only export may have indirect usage

## LOW Confidence (Uncertain)

### src/hooks/
[LOW] src/hooks/useFeatureFlag.ts:7 - useFeatureFlag
  Type: function
  Reason: No static imports found, but name pattern suggests framework usage

---

## Recommendations

HIGH confidence items are safe to remove. Run `/crufthard` to automatically delete them with verification.

MEDIUM/LOW confidence items should be manually reviewed before deletion.
```

**Output format per item:**
```
[CONFIDENCE] file:line - exportName
  Type: const|function|class|type|interface|default
  Reason: Brief explanation
```

### Step 5: Final Output

1. Print the complete report to user
2. Include summary statistics at top
3. If HIGH confidence items found, suggest: "Run `/crufthard` to automatically delete HIGH confidence items with typetest verification"
4. If only MEDIUM/LOW found, suggest: "Manual review recommended for all items"

## Critical Rules

1. **Read-only**: Do NOT delete, modify, or edit ANY files
2. **Comprehensive search**: Check entire codebase for imports, not just obvious files
3. **Exclude correctly**: Do not flag framework entry points or config exports as cruft
4. **Multi-pattern matching**: Use all import pattern variations to avoid false positives
5. **Clear rationale**: Every cruft candidate must have clear reason in report
6. **Conservative confidence**: When uncertain, downgrade to MEDIUM or LOW
7. **Directory grouping**: Group results by directory for easier review
8. **Sort by confidence**: Always show HIGH confidence first

## Edge Cases to Handle

- **CSS/Style modules**: `import styles from './Component.module.css'` - these exports should be excluded
- **JSON imports**: `import data from './data.json'` - config JSON exports should be excluded
- **Asset imports**: `import logo from './logo.png'` - exclude image/asset files
- **Global declarations**: `.d.ts` files may not show direct imports - mark as LOW confidence
- **Monorepo packages**: If package is imported as npm package, its exports aren't cruft
- **Test files**: `*.test.ts`, `*.spec.ts` exports are not cruft (test framework uses them)

## Performance Optimization

- Use Grep tool with appropriate patterns rather than Read tool for large codebases
- Search for imports in parallel where possible (multiple Grep calls in one message)
- Limit output with head_limit if codebase is very large (>10K files)
- Focus on HIGH confidence items for initial analysis

Execute this analysis systematically and generate a clear, actionable report.

# Code Style - Quick Reference

## Core Principles

1. **Immutability**: No data mutation
2. **Pure Functions**: Same input = same output
3. **Self-Documenting**: No comments needed
4. **Early Returns**: No deep nesting
5. **Small Functions**: Single responsibility

---

## Immutability Patterns

| Operation | ✅ DO (Immutable) | ❌ DON'T (Mutates) |
|-----------|-------------------|---------------------|
| **Arrays** |
| Add | `[...arr, item]`, `arr.concat(item)` | `arr.push(item)`, `arr.unshift(item)` |
| Remove | `arr.filter(i => i.id !== id)` | `arr.pop()`, `arr.shift()`, `arr.splice()` |
| Update | `arr.map(i => i.id === id ? {...i, x} : i)` | `arr[0] = value`, `arr.sort()`, `arr.reverse()` |
| **Objects** |
| Add/Update | `{...obj, prop: 'value'}` | `obj.prop = 'value'`, `obj['key'] = 'value'` |
| Remove | `const {remove, ...rest} = obj` | `delete obj.prop` |
| Nested | `{...obj, nested: {...obj.nested, x}}` | `obj.nested.x = 'value'` |
| Merge | `{...obj1, ...obj2}`, `Object.assign({}, a, b)` | `Object.assign(obj, updates)` |


## Functional Patterns

**Pure Functions**: Same input → same output, no side effects
✅ `calculateTotal(items)` ❌ `calculateTotal(items, externalTaxRate)`

**Side Effects**: Isolate (validate pure, then DB call) or return deferred `{data, sideEffects: {sendEmail: () => ...}}`

**Array Methods**: Use `.map()`, `.filter()`, `.reduce()`, `.find()`, `.some()`, `.every()` ❌ No `.forEach()` for transformations, no mutation inside methods


## Naming Conventions

| Type | ✅ DO | ❌ DON'T |
|------|-------|----------|
| **Functions** | Verbs: `calculateTotal`, `validateUser` | `doStuff`, `process`, `manager` |
| **Booleans** | `is/has/can/should`: `isValid`, `hasPermission` | `valid`, `permission` |
| **Event Handlers** | `handle/on`: `handleClick`, `onUserLogin` | `click`, `userLogin` |
| **Types** | PascalCase nouns: `User`, `UserProfile` | `Data`, `Info`, `Item` (too generic) |
| **Constants** | UPPER_SNAKE: `MAX_RETRY_ATTEMPTS` | `maxRetryAttempts` (use for derived) |
| **Variables** | camelCase: `userProfile`, `validationErrors` | `u`, `usr`, `cfg` (abbreviations) |
| **Files** | kebab-case: `user-service.ts`, `auth-middleware.ts` | `UserService.ts` (PascalCase) |


## Structure Preferences

### Early Returns (Guard Clauses)

✅ Check conditions early, throw/return immediately
❌ Nested if/else chains (hard to read)

### No Deep Nesting (Max 2 Levels)

✅ Use `.filter()`, `.map()`, extract helper functions
❌ Nested loops with conditionals inside

### Extract Helper Functions

✅ Break complex functions into small, focused helpers (single responsibility)

---

## Self-Documenting Code

✅ Function names explain purpose (`calculateTotalWithTax`, `isEligibleForDiscount`)
✅ Variables describe content (`activeUsers`, `totalPrice`, `isAdminUser`)
✅ Types use clear names (`CreateUserRequest`, `UserPermissions`)

❌ Abbreviations (`calc`, `a`, `t`, `f`)
❌ Generic names (`process`, `data`, `check`)
❌ Comments to explain unclear code

---

## Function Parameters

✅ Options object for >3 params, named booleans
❌ Long parameter lists, positional booleans (`fn(true, false)` unclear)

---

## TypeScript Preferences

✅ Use `type` over `interface` (more versatile)
✅ Type guards instead of assertions (`value is Type`)
✅ Use `unknown` for truly unknown types, generics for reusable functions

❌ Type assertions (`as Type` bypasses safety)
❌ `any` types (disables type checking)

---

## Quick Checklist

**Before committing, verify:**
- [ ] No data mutation (arrays, objects)
- [ ] Functions are pure (or side effects isolated)
- [ ] No nested conditionals (use early returns)
- [ ] No comments (code is self-documenting)
- [ ] Function/variable names describe purpose
- [ ] Functions <50 lines
- [ ] Max 2 levels of nesting
- [ ] No `any` types
- [ ] Prefer `type` over `interface`
- [ ] Options object for >3 parameters
- [ ] No boolean parameters (use options object)

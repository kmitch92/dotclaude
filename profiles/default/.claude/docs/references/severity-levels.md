# TypeScript Violation Severity Levels

## 🔴 Critical

**Must be fixed before merge/production.**

- **`any` types**: Loses all type safety
  ```typescript
  // ❌ Critical
  const parse = (data: any) => data.value
  
  // ✅ Fix
  const parse = (data: unknown) => {
    if (isValid(data)) return data.value
    throw new Error('Invalid')
  }
  ```

- **Missing schemas at trust boundaries**: External data unvalidated
  ```typescript
  // ❌ Critical
  app.post('/api/user', (req, res) => {
    const user = req.body // No validation!
    db.save(user)
  })
  
  // ✅ Fix
  app.post('/api/user', (req, res) => {
    const user = UserSchema.parse(req.body)
    db.save(user)
  })
  ```

- **Unjustified type assertions**: Bypassing type safety without reason
  ```typescript
  // ❌ Critical
  const user = data as User // No validation
  
  // ✅ Fix
  const user = UserSchema.parse(data)
  ```

- **`@ts-ignore` / `@ts-expect-error` without explanation**: Hiding real type errors
  ```typescript
  // ❌ Critical
  // @ts-ignore
  user.invalidProperty = 'value'
  
  // ✅ Fix (only if truly necessary)
  // @ts-expect-error - Third-party lib missing types, filed issue #123
  user.invalidProperty = 'value'
  ```

## ⚠️ High Priority

**Should be fixed soon, creates maintenance burden.**

- **Multiple function parameters without options object**: Refactor-hostile
  ```typescript
  // ❌ High Priority
  function createUser(
    name: string,
    email: string,
    age: number,
    role: string,
    isActive: boolean
  ) { }
  
  // ✅ Fix
  type CreateUserOptions = {
    name: string
    email: string
    age: number
    role: string
    isActive: boolean
  }
  function createUser(options: CreateUserOptions) { }
  ```

- **Data mutations**: Should use immutable patterns
  ```typescript
  // ❌ High Priority
  const updateUser = (user: User) => {
    user.name = 'New Name'
    return user
  }
  
  // ✅ Fix
  const updateUser = (user: User, name: string): User => ({
    ...user,
    name
  })
  ```

- **`interface` for data structures**: Use `type` for consistency
  ```typescript
  // ❌ High Priority
  interface User {
    id: string
    name: string
  }
  
  // ✅ Fix
  type User = {
    id: string
    name: string
  }
  ```

- **Redefining types in tests**: Tests should import real schemas
  ```typescript
  // ❌ High Priority
  const UserSchema = z.object({ id: z.string() }) // in test file
  
  // ✅ Fix
  import { UserSchema } from '@/schemas/user'
  ```

- **Non-strict tsconfig**: Missing strict mode flags
  ```typescript
  // ❌ High Priority
  {
    "compilerOptions": {
      "strict": false
    }
  }
  
  // ✅ Fix
  {
    "compilerOptions": {
      "strict": true,
      "noUncheckedIndexedAccess": true,
      // ... other strict flags
    }
  }
  ```

## 💡 Nice-to-Have

**Improve over time, low urgency.**

- **Naming conventions**: Inconsistent naming
  ```typescript
  // 💡 Nice-to-Have
  type user = { id: string } // lowercase
  
  // ✅ Better
  type User = { id: string } // PascalCase
  ```

- **File structure**: Types scattered across files
  ```typescript
  // 💡 Nice-to-Have
  // types mixed with implementation
  
  // ✅ Better
  // types in dedicated schema files
  ```

- **Missing utility type usage**: Could be DRY-er
  ```typescript
  // 💡 Nice-to-Have
  type UserUpdate = {
    id?: string
    name?: string
    email?: string
  }
  
  // ✅ Better
  type UserUpdate = Partial<User>
  ```

- **Optional chaining everywhere**: May indicate poor null handling design
  ```typescript
  // 💡 Nice-to-Have
  const name = user?.profile?.name?.firstName?.value
  
  // ✅ Better (fix data model)
  type Profile = {
    name: string // required, not deeply nested
  }
  ```

## Prioritization Framework

When triaging violations:

1. **Critical** → Block merge, fix immediately
2. **High Priority** → Create issue/TODO, fix within sprint
3. **Nice-to-Have** → Backlog, fix opportunistically during refactoring

## Edge Cases

**When `any` might be acceptable (rare):**
- Third-party library with missing/incorrect types (file issue, add to TODO)
- Temporary scaffolding (must have TODO comment with removal date)
- Interop with untyped JavaScript (isolate, add boundary validation)

**When type assertions might be acceptable:**
- After exhaustive Zod validation: `const user = UserSchema.parse(data) as User` (redundant but explicit)
- DOM type refinement: `element as HTMLInputElement` (after null check)
- Type narrowing TypeScript can't infer (rare, add comment explaining why)

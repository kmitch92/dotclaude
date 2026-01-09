# Effect-TS: Functional Effect System

Effect-TS provides a typed functional effect system for complex async flows, error handling, and resource management.

## Core Effect Type

```typescript
import { Effect } from 'effect'

// Effect<Success, Error, Requirements>
type UserEffect = Effect.Effect<User, DatabaseError, DatabaseService>

// Basic effects
const success = Effect.succeed(42)
const failure = Effect.fail(new Error('Failed'))
const async = Effect.promise(() => fetch('/api/data'))

// Transformation
const doubled = Effect.succeed(21).pipe(
  Effect.map(n => n * 2)
)
```

## Typed Error Handling

```typescript
type DatabaseError = { _tag: 'DatabaseError'; message: string }
type ValidationError = { _tag: 'ValidationError'; field: string }

const program = pipe(
  validateUser(data),
  Effect.flatMap(saveUser),
  Effect.catchTag('ValidationError', err => Effect.succeed({ handled: true })),
  Effect.catchTag('DatabaseError', err => Effect.fail({ critical: true }))
)
```

## Dependency Injection with Context

```typescript
class DatabaseService extends Context.Tag('DatabaseService')<
  DatabaseService,
  { query: (sql: string) => Effect.Effect<unknown[]> }
>() {}

const getUsers = Effect.gen(function* (_) {
  const db = yield* _(DatabaseService)
  const users = yield* _(db.query('SELECT * FROM users'))
  return users
})

// Provide implementation
const program = getUsers.pipe(
  Effect.provideService(DatabaseService, { query: (sql) => Effect.succeed([]) })
)
```

## When to Use Effect

✅ **Use Effect for:**
- Complex error handling with multiple typed errors
- Structured concurrency with resource guarantees
- Dependency injection for testable architecture
- Building complex async pipelines
- Resource management (files, connections, locks)
- Cancellable operations

❌ **Don't Use Effect for:**
- Simple CRUD operations (use async/await)
- Team unfamiliar with functional patterns
- Small utility functions
- Straightforward linear flows
- One-off scripts

## Learning Resources

- [Effect-TS Documentation](https://effect.website/)
- [Effect-TS GitHub](https://github.com/Effect-TS/effect)
- [Effect-TS Discord](https://discord.gg/effect-ts)

## Key Takeaway

Effect-TS is powerful but has a learning curve. Use it when complexity justifies the abstraction. For most standard TypeScript applications, async/await + Zod is sufficient.

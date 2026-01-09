# Schema-First Development with Zod

## Core Principle

**Always define schemas first, then derive types from them.** Never define types separately from schemas.

## Basic Pattern

```typescript
import { z } from 'zod'

// Schema is source of truth
const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  role: z.enum(['admin', 'user', 'guest']),
  createdAt: z.date(),
})

// Type derived from schema
type User = z.infer<typeof UserSchema>

// Runtime validation
const parseUser = (data: unknown): User => {
  return UserSchema.parse(data) // Throws if invalid
}
```

## When to Use

- **API boundaries**: Validate external data entering your system
- **External data**: User input, file parsing, third-party APIs
- **Config files**: Application configuration from JSON/YAML/ENV
- **Database results**: Validate data from database queries
- **Message queues**: Validate messages from queues/streams

## Why Schema-First

1. **Single source of truth**: Schema defines both runtime and compile-time constraints
2. **Runtime + compile-time safety**: Zod validates at runtime, TypeScript checks at compile time
3. **Self-documenting**: Schema clearly shows data structure and constraints
4. **Refactor-safe**: Change schema once, types update everywhere
5. **Test-friendly**: Tests use real schemas, ensuring production parity

## Advanced Patterns

See `@~/.claude/docs/examples/schema-composition.md` for composition, extension, and inheritance patterns.

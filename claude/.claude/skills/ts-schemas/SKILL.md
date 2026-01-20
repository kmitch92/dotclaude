---
name: ts-schemas
description: Schema-first development with Zod. Runtime validation, type derivation, schema composition, extension and inheritance patterns.
---

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

## Composing Nested Schemas

Build complex schemas by composing smaller, reusable ones:

```typescript
const AddressDetailsSchema = z.object({
  houseNumber: z.string(),
  houseName: z.string().optional(),
  addressLine1: z.string().min(1),
  addressLine2: z.string().optional(),
  city: z.string().min(1),
  postcode: z.string().regex(/^[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}$/i),
})

const PayingCardDetailsSchema = z.object({
  cvv: z.string().regex(/^\d{3,4}$/),
  token: z.string().min(1),
})

const PostPaymentsRequestV3Schema = z.object({
  cardAccountId: z.string().length(16),
  amount: z.number().positive(),
  source: z.enum(["Web", "Mobile", "API"]),
  accountStatus: z.enum(["Normal", "Restricted", "Closed"]),
  lastName: z.string().min(1),
  dateOfBirth: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  payingCardDetails: PayingCardDetailsSchema,
  addressDetails: AddressDetailsSchema,
  brand: z.enum(["Visa", "Mastercard", "Amex"]),
})

// Derive types from schemas
type AddressDetails = z.infer<typeof AddressDetailsSchema>
type PayingCardDetails = z.infer<typeof PayingCardDetailsSchema>
type PostPaymentsRequestV3 = z.infer<typeof PostPaymentsRequestV3Schema>

// Use schemas at runtime boundaries
export const parsePaymentRequest = (data: unknown): PostPaymentsRequestV3 => {
  return PostPaymentsRequestV3Schema.parse(data)
}
```

## Schema Extension and Inheritance

```typescript
// Base entity pattern
const BaseEntitySchema = z.object({
  id: z.string().uuid(),
  createdAt: z.date(),
  updatedAt: z.date(),
})

// Extend base schema
const CustomerSchema = BaseEntitySchema.extend({
  email: z.string().email(),
  tier: z.enum(["standard", "premium", "enterprise"]),
  creditLimit: z.number().positive(),
})

type Customer = z.infer<typeof CustomerSchema>
```

## Schema Usage in Tests

**CRITICAL**: Tests must import real schemas from production code, never redefine them.

```typescript
// ❌ WRONG - Defining schemas in test files
const ProjectSchema = z.object({
  id: z.string(),
  workspaceId: z.string(),
  ownerId: z.string().nullable(),
  name: z.string(),
  createdAt: z.coerce.date(),
  updatedAt: z.coerce.date(),
})

// ✅ CORRECT - Import schemas from shared package
import { ProjectSchema, type Project } from "@your-org/schemas"

// ✅ CORRECT - Test factories using real schemas
const getMockProject = (overrides?: Partial<Project>): Project => {
  const baseProject = {
    id: "proj_123",
    workspaceId: "ws_456",
    ownerId: "user_789",
    name: "Test Project",
    createdAt: new Date(),
    updatedAt: new Date(),
  }

  const projectData = { ...baseProject, ...overrides }

  // Validate against real schema to catch type mismatches
  return ProjectSchema.parse(projectData)
}
```

## Why This Matters

- **Type Safety**: Ensures tests use the same types as production code
- **Consistency**: Changes to schemas automatically propagate to tests
- **Maintainability**: Single source of truth for data structures
- **Prevents Drift**: Tests can't accidentally diverge from real schemas

## Implementation Checklist

- ☐ All domain schemas exported from shared schema package/module
- ☐ Test files import schemas from shared location
- ☐ Mock data factories use real types derived from real schemas
- ☐ If schema isn't exported, add to exports (don't duplicate)

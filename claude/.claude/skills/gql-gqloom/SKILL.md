---
name: gql-gqloom
description: GQLoom GraphQL schema generation with Zod. Two-level schema architecture, ZodWeaver, enum/object decorators, resolver patterns, AppSync integration.
---

# GQLoom GraphQL Schema Generation

Code-first GraphQL schema generation using GQLoom with Zod schemas.

## Core Principle

**Two-Level Schema Architecture**: Separate browser-safe common schemas from GQLoom-enhanced schemas to maintain clean boundaries and avoid Zod instance mismatches.

## Critical Constraint

**ALL schema files must import Zod from a centralized generator module, NOT directly from 'zod':**

```typescript
// ✅ CORRECT - Avoids Zod instance mismatch
import { z } from '@common/gqloom-generator'

// ❌ WRONG - Causes Zod instance mismatch errors
import { z } from 'zod'
```

## Two-Level Schema Architecture

### Level 1: Common Schemas (Browser-Safe)

Location: `/src/common/schemas/{service}/`

Purpose: Define domain types and inputs without GQLoom imports. Safe for browser consumption.

```typescript
// /src/common/schemas/orders/types.ts
import { z } from '@common/gqloom-generator'

// Domain type schemas - no GQLoom decorators
export const OrderSchema = z.object({
  id: z.string().uuid(),
  customerId: z.string().min(1),
  status: z.enum(['pending', 'processing', 'completed', 'cancelled']),
  total: z.number().nonnegative(),
  createdAt: z.date(),
})

// Derive types from schemas
export type Order = z.infer<typeof OrderSchema>
```

```typescript
// /src/common/schemas/orders/inputs.ts
import { z } from '@common/gqloom-generator'

export const CreateOrderInputSchema = z.object({
  customerId: z.string().min(1),
  items: z.array(z.object({
    productId: z.string(),
    quantity: z.number().int().positive(),
  })).min(1),
})

export type CreateOrderInput = z.infer<typeof CreateOrderInputSchema>
```

### Level 2: GQLoom-Enhanced Schemas (Server-Only)

Location: `/src/services/{service}/src/gqloom/resolvers.ts`

```typescript
// /src/services/orders/src/gqloom/resolvers.ts
import { z } from '@common/gqloom-generator'
import { asObjectType, asEnumType } from '@gqloom/zod'
import { resolver, query, mutation } from '@gqloom/core'
import { OrderSchema } from '@common/schemas/orders/types'

// Enhance with GQLoom decorators
export const OrderStatus = z
  .enum(['pending', 'processing', 'completed', 'cancelled'])
  .superRefine(asEnumType({
    name: 'OrderStatus',
    valuesConfig: {
      pending: { description: 'Awaiting processing' },
      completed: { description: 'Order delivered' },
    },
  }))

export const Order = OrderSchema.superRefine(asObjectType({
  name: 'Order',
  description: 'Customer order',
}))
```

## GQLoom Decorator Patterns

### Enum Decoration

```typescript
export const Priority = z.enum(['LOW', 'MEDIUM', 'HIGH']).superRefine(
  asEnumType({
    name: 'Priority',
    valuesConfig: {
      LOW: { description: 'Low priority' },
      MEDIUM: { description: 'Medium priority' },
      HIGH: { description: 'High priority' },
    },
  })
)
```

### Object Decoration

```typescript
export const User = z
  .object({
    id: z.string().uuid(),
    email: z.string().email(),
    name: z.string().min(1),
  })
  .superRefine(asObjectType({
    name: 'User',
    description: 'Application user',
  }))
```

### Union Types (require __typename)

```typescript
const Cat = z.object({
  __typename: z.literal('Cat').nullish(),
  name: z.string(),
  loveFish: z.boolean().optional(),
})

const Dog = z.object({
  __typename: z.literal('Dog').nullish(),
  name: z.string(),
  loveBone: z.boolean().optional(),
})

const Animal = z.union([Cat, Dog]).superRefine(
  asUnionType({
    name: 'Animal',
    resolveType: (it) => (it.loveFish !== undefined ? 'Cat' : 'Dog'),
  })
)
```

### Circular References (require z.lazy)

```typescript
type CategoryType = z.infer<typeof CategorySchema>

const CategorySchema: z.ZodType<CategoryType> = z.lazy(() =>
  z.object({
    id: z.string().uuid(),
    name: z.string(),
    parent: CategorySchema.nullish(),
    children: z.array(CategorySchema).default([]),
  }).superRefine(asObjectType({ name: 'Category' }))
)
```

## Resolver Patterns

### Pattern 1: Stub Resolvers (AppSync Lambda)

For AppSync, resolvers return null/throw - actual resolution in Lambda:

```typescript
// ✅ Stub resolver - AppSync Lambda handles actual resolution
export const orderResolver = resolver.of(Order, {
  order: query(Order.nullish(), {
    input: { id: z.string().uuid() },
    resolve: () => {
      throw new Error('Resolved by AppSync Lambda')
    },
  }),

  createOrder: mutation(Order, {
    input: { data: CreateOrderInputSchema },
    resolve: () => {
      throw new Error('Resolved by AppSync Lambda')
    },
  }),
})
```

### Pattern 2: Direct Resolvers (Non-AppSync)

For Apollo, Yoga, etc., resolvers contain actual implementation:

```typescript
// ✅ Direct resolver with implementation
export const orderResolver = resolver.of(Order, {
  order: query(Order.nullish(), {
    input: { id: z.string().uuid() },
    resolve: async ({ id }) => {
      return orderService.findById(id)
    },
  }),

  orders: query(z.array(Order), {
    input: {
      status: OrderStatus.nullish(),
      limit: z.number().int().positive().default(20),
    },
    resolve: async ({ status, limit }) => {
      return orderService.findAll({ status, limit })
    },
  }),

  createOrder: mutation(Order, {
    input: { data: CreateOrderInputSchema },
    resolve: async ({ data }) => {
      return orderService.create(data)
    },
  }),

  // Field resolver - receives parent as first argument
  customer: field(Customer.nullish(), {
    resolve: async (order) => {
      return customerService.findById(order.customerId)
    },
  }),
})
```

## Connection Types (Pagination)

```typescript
export function createConnectionTypes<T extends z.ZodTypeAny>(
  nodeSchema: T,
  typeName: string
) {
  const Edge = z.object({
    node: nodeSchema,
    cursor: z.string(),
  }).superRefine(asObjectType({ name: `${typeName}Edge` }))

  const PageInfo = z.object({
    hasNextPage: z.boolean(),
    hasPreviousPage: z.boolean(),
    startCursor: z.string().nullish(),
    endCursor: z.string().nullish(),
  }).superRefine(asObjectType({ name: 'PageInfo' }))

  const Connection = z.object({
    edges: z.array(Edge),
    pageInfo: PageInfo,
  }).superRefine(asObjectType({ name: `${typeName}Connection` }))

  return { Edge, PageInfo, Connection }
}

// Usage
const { Connection: OrderConnection } = createConnectionTypes(Order, 'Order')
```

## Schema Generation Pipeline

### Generator Module

```typescript
// /src/common/gqloom-generator/index.ts
import { weave } from '@gqloom/core'
import { ZodWeaver } from '@gqloom/zod'
import { printSchema } from 'graphql'

export { z } from 'zod'  // Single source for z

export function generateSchemaString(...resolvers: any[]): string {
  const schema = weave(ZodWeaver, ...resolvers)
  return printSchema(schema)
}
```

### Service Generation Script

```typescript
// /src/services/orders/scripts/generate-schema.ts
import { writeFileSync } from 'fs'
import { generateSchemaString } from '@common/gqloom-generator'
import { orderResolver } from '../src/gqloom/resolvers'

const schema = generateSchemaString(orderResolver)
writeFileSync('schema/schema.graphql', schema)
```

## Common Gotchas

### Zod Instance Mismatch

```typescript
// ❌ WRONG - Different Zod instances cause runtime errors
import { z } from 'zod'          // file1.ts
import { z } from '@gqloom/zod'  // file2.ts - different instance!

// ✅ CORRECT - Single instance
import { z } from '@common/gqloom-generator'  // everywhere
```

### Missing __typename in Unions

```typescript
// ❌ WRONG - Can't distinguish at runtime
const Animal = z.union([Cat, Dog])

// ✅ CORRECT - Add __typename literal
const Cat = z.object({
  __typename: z.literal('Cat').nullish(),
  ...
})
```

### Circular Reference Without z.lazy()

```typescript
// ❌ WRONG - Error: Block-scoped variable used before declaration
const Category = z.object({ parent: Category })

// ✅ CORRECT - Use z.lazy()
const Category: z.ZodType<CategoryType> = z.lazy(() =>
  z.object({ parent: Category.nullish() })
)
```

## Directory Structure

```
src/
├── common/
│   ├── gqloom-generator/
│   │   └── index.ts              # Centralized z export
│   └── schemas/
│       └── orders/
│           ├── types.ts          # Browser-safe
│           └── inputs.ts         # Browser-safe
├── services/
│   └── orders/
│       ├── src/gqloom/
│       │   └── resolvers.ts      # GQLoom-enhanced
│       └── scripts/
│           └── generate-schema.ts
└── schema/
    └── schema.graphql            # Generated
```

## Design Checklist

- [ ] All imports use `@common/gqloom-generator` for Zod
- [ ] Common schemas browser-safe (no GQLoom imports)
- [ ] GQLoom decorators only in service gqloom/ directory
- [ ] Enums decorated with `asEnumType({ name, valuesConfig })`
- [ ] Objects decorated with `asObjectType({ name })`
- [ ] Union types include `__typename` literal
- [ ] Circular references use `z.lazy()`
- [ ] Resolver pattern matches target (stub vs direct)
- [ ] Schema generation script exists

## Key Takeaways

1. **Two-level architecture**: Common (browser-safe) vs GQLoom-enhanced (server)
2. **Single Zod source**: Always import from centralized module
3. **Unions need __typename**: For runtime type resolution
4. **Circular refs need lazy**: Use `z.lazy()` for self-references
5. **Stub vs Direct**: Choose resolver pattern based on deployment target

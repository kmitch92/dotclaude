---
name: ts-fundamentals
description: TypeScript strict mode, type safety patterns, type vs interface decisions, branded types for nominal typing.
---

# TypeScript Fundamentals

## Strict Mode Configuration

### Required Configuration

All projects must use this `tsconfig.json`:

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler"
  }
}
```

### Flag Explanations

| Flag | Purpose | Example Violation |
|------|---------|-------------------|
| `strict` | Enables all strict type-checking flags | Implicit `any`, loose null checks |
| `noUncheckedIndexedAccess` | Array/object access returns `T \| undefined` | `arr[0]` without null check |
| `noImplicitOverride` | Require `override` keyword | Class methods overriding without keyword |
| `exactOptionalPropertyTypes` | Optional props can't be `undefined` explicitly | `{ foo?: string \| undefined }` |
| `noUnusedLocals` | Error on unused local variables | `const x = 5; // never used` |
| `noUnusedParameters` | Error on unused function parameters | `function foo(x: string) { }` |
| `noImplicitReturns` | All code paths must return value | Missing return in branch |
| `noFallthroughCasesInSwitch` | Switch cases must break/return | Missing `break` in case |

**Non-negotiable.** Benefits: compile-time safety, prevents runtime surprises, better IDE support, easier refactoring.

---

## Type vs Interface: Prefer `type`

### Default to `type`

```typescript
// ✅ PREFER: type
type User = {
  id: string;
  name: string;
  email: string;
};

type Result<T, E> =
  | { success: true; data: T }
  | { success: false; error: E };

// ❌ AVOID: interface (less flexible for unions and mapped types)
interface User {
  id: string;
  name: string;
  email: string;
}
```

### `type` Advantages

1. **Supports union types**: `type Status = 'pending' | 'active' | 'complete'`
2. **Supports intersection types**: `type Admin = User & Permissions`
3. **Supports mapped types**: `type Readonly<T> = { readonly [K in keyof T]: T[K] }`
4. **Supports conditional types**: `type IsString<T> = T extends string ? true : false`
5. **More consistent**: One syntax for all type definitions
6. **Clearer semantics**: `type` = type alias, `interface` = contract/shape

### When `interface` Might Be Used

**Declaration merging** (augmenting third-party library types):

```typescript
declare global {
  namespace Express {
    interface Request {
      user?: User;
    }
  }
}
```

**Object-oriented patterns** (class contracts, prefer composition over inheritance):

```typescript
interface Repository<T> {
  findById(id: string): Promise<T | null>
  save(entity: T): Promise<void>
}

class UserRepository implements Repository<User> {
  // ...
}
```

### Practical Guidance

- **Default to `type`** for all data structures, unions, intersections
- **Use `interface` only** when you specifically need declaration merging or class contracts
- **Be consistent**: Pick one approach per codebase and stick to it
- **Our preference**: `type` everywhere unless there's a compelling reason otherwise

### Migration Strategy

1. **Don't rush**: Only convert when touching the file anyway
2. **Test thoroughly**: Ensure no behavioral changes
3. **Watch for declaration merging**: May be intentional in third-party type augmentation
4. **Use ESLint**: Configure `@typescript-eslint/consistent-type-definitions` to enforce `type`

---

## Branded Types for Domain Safety

### Problem

TypeScript's structural type system allows mixing semantically different values with the same underlying type:

```typescript
// Both are strings, TypeScript sees them as compatible
type UserId = string
type OrderId = string

function getUser(userId: UserId) { /* ... */ }
function getOrder(orderId: OrderId) { /* ... */ }

const userId: UserId = "user-123"
const orderId: OrderId = "order-456"

getUser(orderId) // ❌ No compile error, but semantically wrong!
```

### Solution: Branded Types

Use intersection types with unique symbols to create incompatible types:

```typescript
// Prevent mixing similar types
type UserId = string & { readonly brand: unique symbol }
type OrderId = string & { readonly brand: unique symbol }
type Email = string & { readonly brand: unique symbol }

const createUserId = (id: string): UserId => id as UserId
const createOrderId = (id: string): OrderId => id as OrderId
const createEmail = (email: string): Email => email as Email

// Type-safe functions
const getUser = (userId: UserId) => { /* ... */ }
const sendEmail = (to: Email) => { /* ... */ }

// ✅ Correct usage
const userId = createUserId('123')
getUser(userId)

// ❌ Compile error - prevents mistakes
const orderId = createOrderId('456')
getUser(orderId) // Type error! OrderId is not assignable to UserId
```

### When to Use

- **Domain models**: Distinguish between different entity IDs
- **Validated strings**: Email, URL, Phone, SSN, etc.
- **Units**: Currency amounts, distances, durations
- **Security**: Sanitized HTML, encrypted data, tokens

### Common Patterns

**Validation + Branding:**

```typescript
type Email = string & { readonly brand: unique symbol }

const createEmail = (input: string): Email => {
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input)) {
    throw new Error(`Invalid email: ${input}`)
  }
  return input as Email
}

// Now Email is both validated AND branded
const email = createEmail("user@example.com")
sendEmail(email) // Type-safe + runtime-validated
```

**Branded Numbers:**

```typescript
type USD = number & { readonly brand: unique symbol }
type EUR = number & { readonly brand: unique symbol }

const usd = (amount: number): USD => amount as USD
const eur = (amount: number): EUR => amount as EUR

function convertUsdToEur(amount: USD): EUR {
  return eur(amount * 0.85)
}

const price = usd(100)
convertUsdToEur(price) // ✅ Type-safe
convertUsdToEur(50) // ❌ Compile error - number is not USD
```

### Why Use Branded Types

1. **Prevents mixing semantically different values**: Compile-time protection against wrong argument order
2. **Self-documenting**: Function signatures clearly show what types are expected
3. **Refactor-safe**: Changing underlying type doesn't break branded type safety
4. **Zero runtime cost**: Brands are purely compile-time, erased during compilation
5. **Forces validation**: Creation functions ensure values are validated before branding

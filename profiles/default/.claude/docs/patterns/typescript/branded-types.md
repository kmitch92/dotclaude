# Branded Types for Domain Safety

## Problem

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

## Solution: Branded Types

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

## When to Use

- **Domain models**: Distinguish between different entity IDs
- **Validated strings**: Email, URL, Phone, SSN, etc.
- **Units**: Currency amounts, distances, durations
- **Security**: Sanitized HTML, encrypted data, tokens

## Common Patterns

### Validation + Branding

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

### Branded Numbers

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

## Why Use Branded Types

1. **Prevents mixing semantically different values**: Compile-time protection against wrong argument order
2. **Self-documenting**: Function signatures clearly show what types are expected
3. **Refactor-safe**: Changing underlying type doesn't break branded type safety
4. **Zero runtime cost**: Brands are purely compile-time, erased during compilation
5. **Forces validation**: Creation functions ensure values are validated before branding

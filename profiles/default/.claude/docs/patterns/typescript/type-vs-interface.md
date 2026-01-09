# Type vs Interface: Prefer `type`

## Recommendation

**Use `type` in all cases for consistency and flexibility.**

## Why `type` Over `interface`

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

## `type` Advantages

1. **Supports union types**: `type Status = 'pending' | 'active' | 'complete'`
2. **Supports intersection types**: `type Admin = User & Permissions`
3. **Supports mapped types**: `type Readonly<T> = { readonly [K in keyof T]: T[K] }`
4. **Supports conditional types**: `type IsString<T> = T extends string ? true : false`
5. **More consistent**: One syntax for all type definitions
6. **Clearer semantics**: `type` = type alias, `interface` = contract/shape

## When `interface` Might Be Used

In rare cases, `interface` may be appropriate:

- **Declaration merging**: Augmenting third-party library types
  ```typescript
  // Extend Express Request type
  declare global {
    namespace Express {
      interface Request {
        user?: User;
      }
    }
  }
  ```

- **Object-oriented patterns**: Class contracts (but prefer composition over inheritance)
  ```typescript
  interface Repository<T> {
    findById(id: string): Promise<T | null>
    save(entity: T): Promise<void>
  }
  
  class UserRepository implements Repository<User> {
    // ...
  }
  ```

## Practical Guidance

- **Default to `type`** for all data structures, unions, intersections
- **Use `interface` only** when you specifically need declaration merging or class contracts
- **Be consistent**: Pick one approach per codebase and stick to it
- **Our preference**: `type` everywhere unless there's a compelling reason otherwise

## Migration Strategy

If you have an existing codebase with `interface`:

1. **Don't rush**: Only convert when touching the file anyway
2. **Test thoroughly**: Ensure no behavioral changes
3. **Watch for declaration merging**: May be intentional in third-party type augmentation
4. **Use ESLint**: Configure `@typescript-eslint/consistent-type-definitions` to enforce `type`

## Further Reading

- [TypeScript Handbook: Interfaces vs Type Aliases](https://www.typescriptlang.org/docs/handbook/2/everyday-types.html#differences-between-type-aliases-and-interfaces)
- [TypeScript Deep Dive: Interfaces vs Types](https://basarat.gitbook.io/typescript/type-system/types-vs-interfaces)

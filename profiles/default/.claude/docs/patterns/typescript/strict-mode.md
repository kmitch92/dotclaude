# TypeScript Strict Mode Configuration

## Required Configuration

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

## Flag Explanations

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

## When

**All projects, non-negotiable.** This configuration should be in every `tsconfig.json`.

## Why

- **Compile-time safety**: Catches errors before runtime
- **Prevents runtime surprises**: Forces explicit handling of edge cases
- **Better IDE support**: More accurate autocomplete and error detection
- **Maintenance**: Easier to refactor safely

---
name: typescript
description: TypeScript and Zod rules and preferences. Read by workers when a task brief lists this file.
disable-model-invocation: true
---

## Compiler

- Strict mode always on: `strict`, `noUncheckedIndexedAccess`, `noImplicitOverride`, `exactOptionalPropertyTypes`, `noUnusedLocals`, `noUnusedParameters`, `noImplicitReturns`, `noFallthroughCasesInSwitch`.
- Never weaken strictness to work around an error — fix the type.

## Type definitions

- Prefer `type` over `interface` in all cases — supports unions, intersections, mapped types.
- Never write `interface X extends z.infer<Schema>` — silently drops fields on a mapped/branded schema. Use `type X = Y & {...}` instead.
- Use branded types for domain IDs so semantically different IDs can't be passed to the wrong function.
- Use discriminated unions for state machines, result types, and variant data.
- Prefer utility types (`Pick`, `Omit`, `Partial`, `Required`, `Record`, `NonNullable`) over hand-rolled equivalents.

## Schemas (Zod)

- Define the schema first; derive the type with `z.infer<typeof Schema>`. Never define a type separately from its schema.
- If the project has `src/common/schemas/`, all entity schemas live there — never redefine elsewhere.
- Follow any project-specific rule in `AGENTS.md` in the schemas directory before changing a schema.
- Compose schemas with `.extend()`, `.merge()`, `.pick()` rather than duplicating fields.
- In tests, import schemas/types from source and build test data by parsing overrides through the real schema — never redefine inline.
- Narrow `unknown` with a schema-backed type guard (`Schema.safeParse(value).success`), not a type assertion.

## Never use `any`

- Use `unknown` plus a type guard or schema parse instead.
- Never use `@ts-ignore` or a type assertion (`as T`) to bypass a type error — fix or validate instead.

## Immutability & purity

- No data mutation — `readonly` arrays/properties, spread updates rather than in-place edits.
- Prefer pure functions: same input, same output, no side effects, where the problem allows it.

## Effect-TS

- Use for complex error handling, structured concurrency, dependency injection, or complex async pipelines.
- Skip for simple CRUD or small utilities.

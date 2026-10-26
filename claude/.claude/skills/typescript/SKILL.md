---
name: typescript
description: Give the TypeScript and Zod rules and preferences. Workers read this file when a task brief names it.
disable-model-invocation: true
---

## Compiler

- Strict mode always on: `strict`, `noUncheckedIndexedAccess`, `noImplicitOverride`, `exactOptionalPropertyTypes`, `noUnusedLocals`, `noUnusedParameters`, `noImplicitReturns`, `noFallthroughCasesInSwitch`.
- Never weaken strictness to work around an error. Repair the type.

## Type definitions

- Use `type`, not `interface`. A `type` can be a union, an intersection, or a mapped type.
- Never write `interface X extends z.infer<Schema>`. That pattern drops fields from a mapped or branded schema, with no warning.
- Write `type X = Y & {...}` as the alternative.
- Use branded types for domain IDs. The compiler stops a mismatched ID from reaching the incorrect function.
- Use discriminated unions for state machines, result types, and variant data.
- Prefer utility types (`Pick`, `Omit`, `Partial`, `Required`, `Record`, `NonNullable`). Do not hand-roll the same type.

## Schemas (Zod)

- Write the schema first. Derive the type from it with `z.infer<typeof Schema>`.
- Never write a type on its own, apart from the schema.
- If the project has `src/common/schemas/`, keep each entity schema there. Never redefine a schema anywhere else.
- Check `AGENTS.md` in the schemas directory for a project rule. Follow it before you change a schema.
- Compose schemas with `.extend()`, `.merge()`, `.pick()`. Do not duplicate fields by hand.
- In a test, import the schema and the type from the source.
- Parse each override through that schema to build the test data. Never redefine the schema inline.
- Narrow `unknown` with a schema-backed type check (`Schema.safeParse(value).success`), not a type assertion.

## Never use `any`

- Use `unknown`, with a type check or a schema parse.
- Never use `@ts-ignore` or a type assertion (`as T`) to bypass a type error. Repair the type, or validate it.

## Immutability & purity

- Do not mutate data. Use `readonly` arrays and properties.
- Apply updates with a copy, not an edit of the initial data.
- Prefer pure functions. The same input must give the same output.
- A pure function has no side effect, if the problem lets it.

## Effect-TS

- Use Effect-TS for a complex error, or for structured concurrency.
- Use Effect-TS to give a dependency to a function, or for a complex async pipeline.
- Skip Effect-TS for plain CRUD work, or for a small utility.

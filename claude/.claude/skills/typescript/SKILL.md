---
name: typescript
description: Give the TypeScript and Zod rules and preferences. Workers read this file when a task brief names it.
disable-model-invocation: true
---

## Compiler

- Strict mode always on: `strict`, `noUncheckedIndexedAccess`, `noImplicitOverride`, `exactOptionalPropertyTypes`, `noUnusedLocals`, `noUnusedParameters`, `noImplicitReturns`, `noFallthroughCasesInSwitch`.
- Never weaken strictness to work around an error, and repair the type instead.

## Type definitions

- Use `type`, not `interface`, because a `type` can be a union, an intersection, or a mapped type.
- Never write `interface X extends z.infer<Schema>`, since that pattern drops fields from a mapped or branded schema with no warning. Write `type X = Y & {...}` as the alternative.
- Use branded types for domain IDs, so the compiler stops a mismatched ID from reaching the wrong function.
- Use discriminated unions for state machines, result types, and variant data.
- Prefer utility types (`Pick`, `Omit`, `Partial`, `Required`, `Record`, `NonNullable`) rather than hand-rolling the same type.

## Schemas (Zod)

- Write the schema first, then derive the type from it with `z.infer<typeof Schema>`. Never write a type on its own, apart from the schema.
- If the project has `src/common/schemas/`, keep each entity schema there, and never redefine a schema anywhere else.
- Check `AGENTS.md` in the schemas directory for a project rule, and follow it before you change a schema.
- Compose schemas with `.extend()`, `.merge()`, `.pick()`, rather than duplicating fields by hand.
- In a test, import the schema and the type from the source, then parse each override through that schema to build the test data. Never redefine the schema inline.
- Narrow `unknown` with a schema-backed type check (`Schema.safeParse(value).success`), not a type assertion.

## Never use `any`

- Use `unknown`, with a type check or a schema parse.
- Never use `@ts-ignore` or a type assertion (`as T`) to bypass a type error, and repair the type, or validate it, instead.

## Immutability & purity

- Do not mutate data, and use `readonly` arrays and properties instead.
- Apply updates with a copy of the data, rather than an edit of the original.
- Prefer pure functions, where the same input always gives the same output and there is no side effect, if the problem allows it.

## Effect-TS

- Use Effect-TS for a complex error, for structured concurrency, to give a dependency to a function, or for a complex async pipeline.
- Skip Effect-TS for plain CRUD work, or for a small utility.

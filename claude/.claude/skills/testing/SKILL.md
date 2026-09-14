---
name: testing
description: Test-writing rules and preferences (TDD, behavioral testing). Read by workers when a task brief lists this file.
disable-model-invocation: true
---

## What a test verifies

- Test observable behavior from the user's perspective (human, API consumer, calling system) — not internal implementation.
- Treat implementation as a black box: assert only on inputs, outputs, observable side effects.
- Test only through the public API; never import or assert on internals, private methods, or component state.
- Reject unit/integration as the organizing question; ask whether the test proves expected behavior.

## RED phase

- Write the failing test before any production code exists.
- Confirm it fails for the expected reason (missing behavior), not an unrelated error (typo, wrong import, syntax error).

## Structure

- Group tests by feature/workflow, not file or function — no 1:1 mapping to implementation files.
- Name tests so they read like a specification of behavior.
- Arrange-Act-Assert: set up, execute, verify, in that order.

## Schemas & test data

- Import schemas/types from the project source; never redefine a schema inline in a test.
- Factories return a complete valid object with sensible defaults, accept partial overrides, and validate the result by parsing it through the real schema.
- Compose factories for nested objects rather than duplicating structure.

## What to test

- Cover: happy path, edge cases, error handling, side effects, full user workflows.
- Don't cover: implementation details, internal/private functions, framework internals, mock internals.

## Code standards in tests

- No `any` — use `unknown` with narrowing. Immutable data only, never mutate fixtures. No comments — self-documenting names instead.
- ES `import` only; never `require()`. For module-reset/mock-reload, use `jest.resetModules()` plus a dynamic `await import('./module')`.
- Coverage is a side effect of testing every behavior, never a target pursued directly.

## Running tests

- Run only the specific test file(s) covering the change being verified.
- Never run the full suite unless explicitly asked — full runs are expensive and are the user's/CI's responsibility.

## Self-correction

- Importing internals → test the public API instead. Asserting on state/props → assert on output.
- Mirroring implementation file structure → reorganize by behavior. Defining a schema inline → import from source.
- Writing the test after the code → stop, this is not TDD.

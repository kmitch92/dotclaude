---
name: testing
description: The rules and preferences to write tests (TDD, behavioral testing). Workers read this file when a task brief names it.
disable-model-invocation: true
---

## What a test verifies

- Test observable behavior from the perspective of the user (human, API consumer, system), not the inner working of the code.
- Use the code as a black box: assert only on input, output, and observable side effects.
- Test only through the public API. Never import or assert on internals, private methods, or component state.
- Reject unit/integration as the organizing question. Check if the test proves expected behavior.

## RED phase

- Write the failing test before you write the production code.
- Make sure it fails for the expected cause: a missing behavior.
  - Do not accept an unrelated error, such as a typo, an incorrect import, or a syntax error.

## Structure

- Group tests by behavior or workflow, not by file or function.
  - Do not map tests one-to-one to the file structure of the code.
- Name tests so they read like a specification of behavior.
- Arrange-Act-Assert: set up, do the step, check the result, in that sequence.

## Schemas & test data

- Import schemas and data types from the project source, and never redefine a schema inline in a test.
- Factories return a full, correct object with sensible defaults.
  - A factory can accept partial overrides.
  - Each factory must check its result against the schema it came from.
- Compose factories for nested objects. Do not duplicate structure.

## What to test

- Include the happy path, and edge conditions, and error handling, and side effects, and full user workflows.
- Do not include the internal structure of the code, internal or private functions, and framework internals, or mock internals.

## Code standards in tests

- No `any` — use `unknown` with narrowing.
  - Immutable data only, never mutate fixtures.
  - No comments, only self-documenting names.
- ES `import` only. Never `require()`. For module-reset/mock-reload, use `jest.resetModules()` plus a dynamic `await import('./module')`.
- Coverage is a side effect when tests include each behavior. This coverage is never a target to pursue alone.

## Running tests

- Run only the test files for the changed code.
- Never run the full suite unless someone explicitly requests it.
  - Full runs are expensive.
  - The responsibility for them belongs to the user or to CI.
- Bare runner commands (`npm test`, `pytest`, `go test ./...`) run everything — always give the test file path or a filter.
- Run the suite one time, never in monitor mode (`vitest run`, not `vitest`, no `--watch`) — monitor mode, by itself, never exits.

## Self-correction

- Self-correct these patterns:
  - Do not import internals. Test the public API.
  - Do not assert on state or props. Assert on output.
  - Do not mirror the file structure of the code. Reorganize the tests by behavior.
  - Do not write a schema inline. Import it from source.
  - Do not write the test after the code. Stop — this is not TDD.

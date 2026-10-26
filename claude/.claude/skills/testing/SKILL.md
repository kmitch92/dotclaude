---
name: testing
description: The rules and preferences to write tests (TDD, behavioral testing). Workers read this file when a task brief names it.
disable-model-invocation: true
---

## What a test verifies

- Test observable behavior from the perspective of the user (human, API consumer, system), not the inner working of the code.
- Use the code as a black box: assert only on input, output, and observable side effects.
- Test only through the public API, and never import or assert on internals, private methods, or component state.
- Reject unit/integration as the organizing question, and check instead if the test proves expected behavior.

## RED phase

- Write the failing test before you write the production code.
- Make sure it fails for the expected cause, a missing behavior, and do not accept an unrelated error, such as a typo, an incorrect import, or a syntax error.

## Structure

- Group tests by behavior or workflow, not by file or function, and do not map tests one-to-one to the file structure of the code.
- Name tests so they read like a specification of behavior.
- Arrange-Act-Assert: set up, do the step, check the result, in that sequence.

## Schemas & test data

- Import schemas and data types from the project source, and never redefine a schema inline in a test.
- Factories return a full, correct object with sensible defaults, can accept partial overrides, and must check their result against the schema they came from.
- Compose factories for nested objects, instead of duplicating structure.

## What to test

- Include the happy path, and edge conditions, and error handling, and side effects, and full user workflows.
- Do not include the internal structure of the code, internal or private functions, and framework internals, or mock internals.

## Code standards in tests

- No `any` — use `unknown` with narrowing, and keep data immutable, never mutating fixtures.
- No comments, only self-documenting names.
- ES `import` only, never `require()`, though for module-reset or mock-reload, use `jest.resetModules()` plus a dynamic `await import('./module')`.
- Coverage is a side effect when tests include each behavior, and is never a target to pursue alone.

## Running tests

- Run only the test files for the changed code.
- Never run the full suite unless someone explicitly requests it, since full runs are expensive, and the responsibility for them belongs to the user or to CI.
- Bare runner commands (`npm test`, `pytest`, `go test ./...`) run everything — always give the test file path or a filter.
- Run the suite one time, never in monitor mode (`vitest run`, not `vitest`, no `--watch`) — monitor mode, by itself, never exits.

## Self-correction

- Self-correct these patterns:
  - Do not import internals, but test the public API instead.
  - Do not assert on state or props, but assert on output instead.
  - Do not mirror the file structure of the code, and reorganize the tests by behavior instead.
  - Do not write a schema inline, but import it from source instead.
  - Do not write the test after the code, and stop, since this is not TDD.
</content>

---
name: backend
description: Backend API and database rules and preferences. Read by workers when a task brief lists this file.
disable-model-invocation: true
---

## Contract-first

- Design the API contract and database schema before writing implementation code; build to it, keeping patterns consistent across endpoints.
- Version APIs properly (`/api/v1/...`) rather than breaking existing clients.
- Keep APIs self-documenting (OpenAPI/GraphQL schema) and enforce referential integrity in the data model.

## Serverless

- Prefer managed services and stateless Lambda functions.
- Initialize SDK/DB clients outside the handler so they're reused across warm invocations — never inside the handler.
- Keep handlers thin (I/O only); put business logic in separate service functions.

## REST API design

- Resource names are plural nouns (`/api/users`), not verbs; nest no more than two levels deep.
- HTTP methods: GET list/read, POST create, PUT full replace, PATCH partial update, DELETE delete.
- 2xx success, 4xx client error, 5xx server error.
- Prefer cursor-based pagination over offset-based.

## Database design

- Schema-first; normalize to 3NF by default, documenting any deliberate denormalization.
- Index every column used in a query predicate or sort key.
- Every table needs a primary key, foreign keys where relational, NOT NULL and unique constraints where required, sane defaults.
- DynamoDB single-table design: define the partition/sort key pattern and any GSI keys before writing access code.
- Write migrations as a safe, reversible step, not an inline schema edit.

## Validation & errors

- Validate all external input with a Zod schema before use; never trust request body, query params, or headers unparsed.
- Return validation failures as 400 with a consistent error shape; wrap success payloads consistently.

## Do / don't

- Do: validate all input, separate handler from business logic, keep type safety end-to-end, keep error responses consistent.
- Don't: create clients inside the handler, skip validation, mix handler and business logic, hardcode secrets, break backward compatibility without versioning.

## Infrastructure

- Test infrastructure locally only (SAM local, LocalStack, `cdk synth`).
- Never deploy to AWS in any environment — leave deployment to the user.

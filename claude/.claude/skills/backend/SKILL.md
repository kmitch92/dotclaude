---
name: backend
description: Backend API and database rules and preferences. Read by workers when a task brief names this file.
disable-model-invocation: true
---

## Contract-first

- Give the API contract and the database schema before you write the code.
- Build the code to that contract.
- Keep the same patterns across endpoints.
- Give each API a version (`/api/v1/...`). Do not break existing clients.
- Keep APIs self-documenting (OpenAPI/GraphQL schema).
- Keep referential integrity correct in the data model.

## Serverless

- Prefer managed systems and stateless Lambda functions.
- Start SDK/DB clients apart from the handler. Use the same clients for each warm start.
- Never start a new client in the handler.
- Keep handlers thin: I/O only.
- Put business logic in its own functions.

## REST API design

- Resource names are plural nouns (`/api/users`), not verbs.
- Do not nest resources more than two levels deep.
- Use `GET` to read a resource, and `POST` to add one.
- Use `PUT` to replace a resource fully, and `PATCH` to update part of it.
- Use `DELETE` to remove a resource.
- Use 2xx codes for success, 4xx codes for a client error, and 5xx codes for a server error.
- Prefer cursor-based pagination above offset-based pagination.

## Database design

- Make the schema first. Normalize it to 3NF by default.
- Write down each deliberate denormalization.
- Index each column used in a query predicate or sort key.
- Each table must have a primary key.
- Add `foreign keys` where the data is relational.
- Add NOT NULL and unique constraints where required.
- Give each column a sane default.
- For DynamoDB, use a single table.
- Give the partition key pattern and the sort key pattern.
- Give each GSI key before you write the access code.
- Write migrations as a safe, reversible step, not an inline schema edit.

## Validation & errors

- Validate all external input with a Zod schema before you use it.
- Never trust the request body, the query params, or the headers without a check.
- Return validation failures as 400, with the same error shape each time.
- Put success payloads in the same shape too.

## Do / don't

- Do: validate all input.
- Keep the handler apart from the business logic.
- Keep type safety from end to end.
- Keep error responses the same.
- Do not make clients in the handler.
- Do not skip validation.
- Do not mix the handler and the business logic.
- Do not hardcode secrets.
- Do not break earlier clients without a version change.

## Infrastructure

- Test infrastructure locally only (SAM local, LocalStack, `cdk synth`).
- Never deploy to AWS.
- Give deployment control to the user.

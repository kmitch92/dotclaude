# ADR Format

ADRs live in `docs/adr/` and use sequential numbers, for example `0001-slug.md`, `0002-slug.md`, and so on.

Make the `docs/adr/` directory only when the first ADR is necessary.

## Template

```md
# {Short title of the decision}

{1-3 sentences: what's the context, what did we decide, and why.}
```

The template above is sufficient. An ADR can be a single paragraph. The value is in the record of *that* a decision happened, and of *why* it happened. The value is not in the sections you fill out.

## Optional sections

Add these only when they add value. Most ADRs do not use them.

- Add a `Status` entry to the frontmatter (`proposed | accepted | deprecated | superseded by ADR-NNNN`) when someone can revisit the decision.
- Add a `Considered Options` section only when the rejected selections are worth remembering.
- Add a `Consequences` section only when it calls out downstream effects that are not obvious.

## Numbering

Examine `docs/adr/` for the highest existing number. Add one to it.

## When to offer an ADR

All three of these must be correct:

First: the selection must be hard to change back. The cost of a change of mind, after the decision, is meaningful.

Second: the selection must surprise a reader who has no context. A future reader will look at the code and wonder "why on earth did they do it this way?"

Third: the selection must be the result of an actual trade-off. There were actual alternatives, and you picked one for a clear cause.

If a decision is easy to change back, skip it. You will change it back immediately anyway. If nobody finds it surprising, nobody will wonder why. If there was no actual alternative, you have nothing to record, beyond "we did the obvious thing."

### What qualifies

- Write down the architectural shape, for example "We're using a monorepo." or "The write model is event-sourced, the read model is projected into Postgres."
- Write down integration patterns between contexts, for example "Ordering and Billing communicate via domain events, not synchronous HTTP."
- Write down technology selections that have lock-in: the database, the message bus, the auth provider, or the deployment target.
- Write only about the libraries that can cost a quarter to replace.
- Write down boundary decisions and scope decisions, for example "Customer data is owned by the Customer context; other contexts reference it by ID only." The explicit no-s are as valuable as the yes-s.
- Write down deliberate deviations from the obvious path, for example "We're using manual SQL instead of an ORM because X."
- Write this down when a reasonable reader can think the opposite is correct.
- Write this down, so the next engineer does not "fix" something that was deliberate.
- Write down constraints you cannot see in the code, for example "We can't use AWS because of compliance requirements." or "Response times must be under 200ms because of the partner API contract."
- Write down a rejected alternative when its cause is not obvious.
- Record the cause, for example, when you think about GraphQL, but pick REST, for a cause others cannot see.
- Record it, or someone will suggest GraphQL again in six months.

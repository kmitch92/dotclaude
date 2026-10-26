# CONTEXT.md Format

## Structure

```md
# {Context Name}

{One or two sentence description of what this context is and why it exists.}

## Language

**Order**:
{A one or two sentence description of the term}
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request

**Customer**:
A person or organization that places orders.
_Avoid_: Client, buyer, account
```

## Rules

- **Have an opinion.**
  - When many words name the same concept, pick the best one.
  - Record the others below `_Avoid_`.
- **Keep definitions tight.** Use one or two sentences at most. State what it is, not what it does.
- **Only include terms that belong to this project.**
  - General concepts of software do not belong.
  - Examples are timeouts, error types, and utility patterns.
  - The project can use them a lot. They do not belong regardless.
  - Before you add a term, check if it is unique to this context, or only a general concept of software.
  - Only the first type belongs.
- **Group terms below subheadings** when natural clusters emerge. If all terms belong to a single area, a flat record works.

## Single vs multi-context repos

**Single context, usual for most repos:** keep one `CONTEXT.md` at the repo root.

**Many contexts:** Keep a `CONTEXT-MAP.md` at the repo root. It names the contexts, where they live, and how they connect to each other:

```md
# Context Map

## Contexts

- [Ordering](./src/ordering/CONTEXT.md) — receives and tracks customer orders
- [Billing](./src/billing/CONTEXT.md) — generates invoices and processes payments
- [Fulfillment](./src/fulfillment/CONTEXT.md) — manages warehouse picking and shipping

## Relationships

- **Ordering → Fulfillment**: Ordering emits `OrderPlaced` events; Fulfillment consumes them to start picking
- **Fulfillment → Billing**: Fulfillment emits `ShipmentDispatched` events; Billing consumes them to generate invoices
- **Ordering ↔ Billing**: Shared types for `CustomerId` and `Money`
```

The skill infers which structure applies, as follows.

- If `CONTEXT-MAP.md` is there, read it to find contexts.
- If only a root `CONTEXT.md` is there, it is a single context.
- If no file is there, make a root `CONTEXT.md` only when you resolve the first term.

When many contexts are there, infer which one connects to the current topic. If unclear, question the user.

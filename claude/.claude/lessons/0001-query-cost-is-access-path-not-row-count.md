---
principle: The access path sets query cost, not table dimension, and row count only risks a timeout defect.
date: 2026-07-09
project: data-processing (product-enrichment feature-generator, Mirakl path)
tags: [postgres, athena-federated-passthrough, query-optimization, index, partial-index, materialized-view, anti-join, seq-scan, access-path, timeout, product-enrichment, mirakl]
---

## The principle

The **access path** the planner uses to *find* qualifying rows sets the runtime cost of a query, not how many rows the table holds.

- A **sequential scan + filter** is O(rows examined).
  - The scan must read each row before it can check the row against the filter.
  - A predicate can cause this type of scan.
  - This occurs when its truth stays hidden until you read the row (for example, `derivedFeatures IS NULL` off a `LEFT JOIN`).
  - All of this dead-weight history costs the same on each scan.
  - Examples include discontinued rows, and out-of-stock rows, and already-processed rows.
- An **index, or a materialized access path,** is ≈ O(rows returned).
  - The planner jumps straight to the rows that qualify.
  - The total table dimension becomes almost irrelevant.

Row count is thus an **amplifier, not the cause**. A latent O(n) scan-and-filter defect stays invisible while the table is sufficiently small. The engine can then check each row directly, in the timeout window. It also stays invisible while rows that qualify are sufficiently dense for `LIMIT n` to fill after only a few rows. It surfaces as a hard failure only after the table becomes larger and the qualifying set gets sparse. The correction is to change the access path, not to shrink the table — you can keep each row and make the query run quickly.

The session surfaced these corollaries.
- **An index is single-table.**
  - "Rows in `products` with no matching `pe` row" names a *relationship between two tables*.
  - No single index can capture this relationship.
  - This fact is why the anti-join resists an index.
  - A **materialized view (which can span tables) is the right instrument** for a cross-table pending-set.
- **A matview does not remove the scan cost.**
  - The cost returns on each refresh.
  - `REFRESH` re-runs the expensive query.
  - You win only if you refresh one time each cycle.
  - You also win only if you iterate many batches against the frozen snapshot.
- **Low-cardinality columns make a weak index target.**
  - The planner ignores an index on a column with too few values that are unique.
  - A **partial index** (`WHERE derivedFeatures IS NULL`) corrects this. It holds only the pending set.
  - It cannot see rows that have no row at all in the indexed table.
- **Optimize the join that costs the most.**
  - The prior `mat_in_stock_skus` matview optimized the *stock* join.
  - The pending-set anti-join stayed a per-row scan.
  - The tool was right, but the join was incorrect.

## Why it matters

The opening diagnosis of the user blamed "millions of rows" and imagined the scan "reaching towards the back of the table," with a physical-position mental model. That model does not survive contact with how a Postgres heap stores rows: there is no stable sequence, and autovacuum churns the table. That framing steers you to the incorrect corrections: shrinking the catalog, paginating "to the back faster," or building the incorrect join into a materialized view, as before. Keep three ideas different from each other. *Cause* is the missing access path. *Amplifier* is the row count. *Lever* is the access path, not deletion. If you mix them, each correction touches a symptom, and the query stays a sticking point. This also connects to a recurring trap in this codebase — the "phantom count". The number that counts is the *pending, in-stock, Parent* cardinality with an access path to it, not the total product count.

## In my own words

> [Gap 2] the stock check matview optimised the first join - a somewhat costly join to a different inventory table and computation of stock on parents from variants. while this probably was necessary it wasn't sufficient, because the join is still large and a scan is still required to evaluate whether or not each row has null derived features or not
>
> [Gap 1] it has to be true because the query used to pass. if the first 1000 rows or whatever the limit is are all df = null then even though the query is flawed it is capable of returning a result. if there wasn't a large number of rows we wouldnt need clever workarounds because the entire catalog would be scannable multiple times in the timeout window.

## Context

The Mirakl path of the product-enrichment feature-generator hit the 15-minute Lambda timeout. The "Athena query" is a federated **passthrough** (`TABLE("mirakl-importer-postgres-datasource".system.query(...))`). It runs in RDS Postgres, not in the S3 scan engine of Athena. The query:

```sql
SELECT p.sku, ... , pe.attributes, ...
FROM products p
LEFT JOIN product_enrichment pe ON p.sku = pe.sku AND pe.locale = 'gb'
INNER JOIN mat_in_stock_skus instock ON p.sku = instock.sku AND channelid = 'GBP'
WHERE p.type = 'Parent' AND pe.derivedFeatures IS NULL
LIMIT :batchSize
```

Run the query in batches across a cycle. The boohoo path (the same `derivedFeatures IS NULL` predicate, CTE-shaped) completes in about 4 minutes. Mirakl has no `pe` row until an enrichment process first runs against a product. So the anti-join spans across two populations: a pe-row with a null `derivedFeatures`, and no pe-row at all. This rules out a plain partial index. It points at a **materialized view of the pending set, refreshed one time each cycle, iterated by PK-join each batch**. The agreed next step, before you build anything, is to run `EXPLAIN (ANALYZE, BUFFERS)` against RDS. This step will identify the seq-scan, name the costly join, and measure the correct pending-set cardinality.

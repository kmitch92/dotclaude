---
principle: A query's cost is set by its access path, not by table size — row count only decides whether a latent scan-and-filter flaw breaches your timeout.
date: 2026-07-09
project: data-processing (product-enrichment feature-generator, Mirakl path)
tags: [postgres, athena-federated-passthrough, query-optimization, index, partial-index, materialized-view, anti-join, seq-scan, access-path, timeout, product-enrichment, mirakl]
---

## The principle

The runtime cost of a query is determined by the **access path** the planner uses to *find* qualifying rows, not by how many rows the table holds.

- A **sequential scan + filter** is O(rows examined): every row must be retrieved before its inclusion criterion can be evaluated. Predicates whose truth "can't be known without pulling the row" (e.g. `derivedFeatures IS NULL` off a `LEFT JOIN`) force this. All dead-weight history (discontinued / out-of-stock / already-processed rows) is paid for on every scan.
- An **index / materialized access path** is ≈ O(rows returned): the planner jumps straight to qualifying rows and total table size becomes almost irrelevant.

Row count is therefore an **amplifier, not the cause**. A latent O(n) scan-and-filter flaw stays invisible while the table is small enough to brute-force inside the timeout window, and while qualifying rows are dense enough that `LIMIT n` fills early. It surfaces as a hard failure only once the table grows and the qualifying set gets sparse. The fix is to change the access path, not to shrink the table — you can keep every row and make the query fast.

Corollaries surfaced in the session:
- **An index is single-table.** "Rows in `products` with no matching `pe` row" is a *relationship between two tables* and cannot be captured by any one index — which is exactly why the anti-join resists indexing and why a **materialized view (which can span tables) is the right instrument** for a cross-table pending-set.
- **A matview doesn't eliminate the scan cost, it amortizes it:** `REFRESH` re-runs the expensive query, so the win only exists if you refresh once per cycle and iterate many batches against the frozen snapshot.
- **Low-cardinality columns index poorly** (planner ignores an unselective index); a **partial index** (`WHERE derivedFeatures IS NULL`) fixes this by holding only the pending set — but it can't see rows that have no row in the indexed table at all.
- **Optimize the join that actually costs.** The prior `mat_in_stock_skus` matview optimized the *stock* join; the pending-set anti-join stayed a per-row scan. Right tool, wrong join.

## Why it matters

The user's opening diagnosis blamed "millions of rows" and imagined the scan "reaching towards the back of the table" — a physical-position mental model that doesn't survive contact with how a Postgres heap actually stores rows (no stable order; autovacuum churns it). That framing steers toward the wrong fixes: shrinking the catalog, paginating "to the back faster", or (as previously) materializing the wrong join. Without separating *cause* (missing access path) from *amplifier* (row count) and *lever* (access path, not deletion), each mitigation treats a symptom and the query stays a sticking point. It also connects to a repeat trap in this codebase — the "phantom count": the number that matters is the *pending, in-stock, Parent* cardinality with an access path to it, not the total product count.

## In my own words

> [Gap 2] the stock check matview optimised the first join - a somewhat costly join to a different inventory table and computation of stock on parents from variants. while this probably was necessary it wasn't sufficient, because the join is still large and a scan is still required to evaluate whether or not each row has null derived features or not
>
> [Gap 1] it has to be true because the query used to pass. if the first 1000 rows or whatever the limit is are all df = null then even though the query is flawed it is capable of returning a result. if there wasn't a large number of rows we wouldnt need clever workarounds because the entire catalog would be scannable multiple times in the timeout window.

## Context

The Mirakl path of the product-enrichment feature-generator was hitting the 15-minute Lambda timeout. The "Athena query" is a federated **passthrough** (`TABLE("mirakl-importer-postgres-datasource".system.query(...))`) — it executes in RDS Postgres, not Athena's S3 scan engine. The query:

```sql
SELECT p.sku, ... , pe.attributes, ...
FROM products p
LEFT JOIN product_enrichment pe ON p.sku = pe.sku AND pe.locale = 'gb'
INNER JOIN mat_in_stock_skus instock ON p.sku = instock.sku AND channelid = 'GBP'
WHERE p.type = 'Parent' AND pe.derivedFeatures IS NULL
LIMIT :batchSize
```

Run in batches across a cycle; the boohoo path (identical `derivedFeatures IS NULL` predicate, CTE-shaped) completes in ~4 min. Mirakl has no `pe` row until an enrichment process first runs against a product, so the anti-join spans two populations (pe-row-with-null-df, and no-pe-row-at-all) — which rules out a plain partial index and points at a **matview of the pending set, refreshed once per cycle, iterated by PK-join per batch**. Agreed next step before building anything: run `EXPLAIN (ANALYZE, BUFFERS)` against RDS to confirm the seq-scan, identify the costly join, and measure the true pending-set cardinality.

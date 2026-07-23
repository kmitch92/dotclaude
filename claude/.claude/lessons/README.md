# Lessons

Principles learned through `/grok` sessions, persisted here for cross-project recall. Each entry links to one lesson — the principle, why it mattered, and the explanation given in the user's own words at the teach-back gate.

## Index

<!-- /grok appends entries here, newest last -->
- [0001 query-cost-is-access-path-not-row-count](0001-query-cost-is-access-path-not-row-count.md) — A query's cost is set by its access path, not table size; row count only decides whether a latent scan-and-filter flaw breaches your timeout.

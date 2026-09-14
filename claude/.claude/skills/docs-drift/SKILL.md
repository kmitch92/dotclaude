---
name: docs-drift
description: Detect and repair documentation drift — walk every tracked markdown file, diff it against commits since its last edit, and fix what's gone stale
disable-model-invocation: true
---

Every tracked `.md` file is a claim about the codebase that commits can silently outdate. Find every doc whose last-edit commit is behind reality, judge it against its own commit range, and fix only what needs it — one file at a time, never a blanket rewrite.

## 1. List tracked docs

```bash
git ls-files '*.md'
```

## 2. Find each doc's last edit

```bash
git log -1 --follow --format='%H %cI %s' -- <doc>
```

`--follow` is required, or a `git mv` resets the date and hides earlier edits.

- No output → untracked doc. Skip, record as skipped, note why.
- Commit is HEAD, or step 3's range is empty → nothing landed since. Report as current.

## 3. Build the commit range

```bash
git log <sha>..HEAD --format='%h %s' --name-only -- . ':!<doc>'
```

Exclude the doc itself. Process the full range even if large — note its size in the report; a long-neglected doc carries the most risk.

## 4. Judge relevance

Read each commit message and judge whether it plausibly touches what the doc describes. Pull the full diff (`git show <sha>`) only when the message is too vague to judge. Judge by content, not path — a commit outside the doc's own directory can still make it wrong (a renamed function, a changed default).

If every commit is irrelevant, report the doc as current and stop.

## 5. Review and repair, one doc at a time

Read the doc in full, read the diffs of the relevant commits, then reconcile: false statements, changed behavior, renamed/deleted things still referenced, new behavior missing. Make the minimum edit that restores accuracy; don't rewrite prose that's still correct. Note anything suspected but not verifiable from the diff.

Open questions answerable from the repo: resolve by investigation, don't ask. Open questions answerable only by the user (deliberate omission? doc still applies? which reading is intended?): ask one at a time, grounded in the diff. Asking is a legitimate outcome — guessing is the failure mode.

## 6. Commit each repaired doc

Docs-only commits, never mixed with code. 1–3 files ideal, 5 soft cap — batch related fixes under the cap, otherwise one commit per doc. Never push, amend, or rebase; commit locally and stop.

## 7. Flag what can't be resolved

If neither investigation nor the user can settle what the doc should say, don't guess or edit the body. Insert a staleness banner after any frontmatter (or as the first line if none):

```
> [!WARNING]
> **Possibly out of date.** Last verified against `<sha>` (`<date>`); `<n>` commits have landed since and the drift could not be resolved. <!-- docs-drift:stale sha=<sha> date=<date> -->
```

The HTML comment is an idempotent marker: replace an existing banner in place rather than stacking a second one; a resolving run removes it. Commit the banner through step 6.

## 8. Report

A table: doc path, last-edit date, commit count, verdict (`current` / `updated` / `stale-flagged` / `skipped`), and what changed or why skipped.

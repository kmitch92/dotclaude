---
name: docs-drift
description: This skill repairs documentation that has gone stale. It walks each tracked markdown file. It checks each file against commits since its last edit.
disable-model-invocation: true
---

Each tracked `.md` file is a claim about the codebase that commits can silently outdate. Find each doc for which the last-edit commit is behind reality. Judge it against its own commit range. Repair only the part that is incorrect. Work one file at a time, and never do a full rewrite.

## 1. List tracked docs

```bash
git ls-files '*.md'
```

## 2. Find each doc's last edit

```bash
git log -1 --follow --format='%H %cI %s' -- <doc>
```

You must use `--follow`, or a `git mv` resets the date and hides earlier edits.

- No output means the repository has no record of the doc. Skip it. Record why.
- Commit is HEAD, or the range from step 3 is empty → nothing landed since. Report as current.

## 3. Build the commit range

```bash
git log <sha>..HEAD --format='%h %s' --name-only -- . ':!<doc>'
```

Exclude the doc itself. Process the full range, large or small — record its dimension in the report. A long-neglected doc holds the most risk.

## 4. Judge relevance

Read each commit message and judge if it plausibly touches what the doc is about. Pull the full diff (`git show <sha>`) only when the message is too vague to judge. Judge by content, not path — a commit external to the directory of the doc can make it incorrect (a renamed function, a changed default).

If each commit is irrelevant, report the doc as current and stop.

## 5. Review and repair, one doc at a time

Read the doc in full. Read the diffs of the related commits. Reconcile incorrect statements, and changed behavior, and renamed or deleted things the doc names, and new behavior the doc does not name. Make the minimum edit that repairs precision. Do not rewrite prose that is correct. Record anything you think is incorrect but the diff does not prove.

Resolve each open question the repo can answer through investigation. Do not put these to the user. Put each open question only the user can answer to the user. Put one at a time, grounded in the diff. Example questions: was the omission deliberate? Does the doc apply now? Is a different reading correct? A question is a legitimate outcome. A guess is the failure mode.

## 6. Commit each repaired doc

Docs-only commits, never mixed with code. Keep it to one to three files, with five as a soft limit. Batch related repairs below the limit, or make one commit for each doc if not. Never push, change, or rebase. Commit locally. Stop.

## 7. Flag what can't be resolved

If investigation and the user cannot resolve what the doc must say, do not guess or edit the body. Put a staleness banner after one frontmatter block (or as the first line if there is none):

```
> [!WARNING]
> **Possibly out of date.** Last verified against `<sha>` (`<date>`); `<n>` commits have landed since and the drift could not be resolved. <!-- docs-drift:stale sha=<sha> date=<date> -->
```

The HTML comment is an idempotent marker. Replace an existing banner. Do not add a second one. A resolving run removes it. Commit the banner through step 6.

## 8. Report

A table with these columns: the doc path, the last-edit date, the commit count, and the verdict (`current` / `updated` / `stale-flagged` / `skipped`). Add what changed, or the cause of the skip.

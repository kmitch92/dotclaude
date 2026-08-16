---
name: docs-drift
description: Detect and repair documentation drift — walk every tracked markdown file, diff it against the commits that landed since its last edit, and fix what's gone stale.
disable-model-invocation: true
---

Repair drift between the repo's markdown docs and the code they describe. Every tracked `.md` file is a claim about the codebase; commits land without updating the claim. This skill finds every doc whose last-edit commit is now behind reality, judges each one against its own commit range, and fixes only the ones that need it — one file at a time, never a blanket rewrite.

## 1. Discover tracked docs

Tracked files only — `node_modules`, build output, and anything gitignored are excluded for free:

```
git ls-files '*.md'
```

## 2. Find each doc's last edit

For every doc, get its true last-edit commit. `--follow` is mandatory — without it, a `git mv` resets the date to the move commit and hides every real edit before it:

```
git log -1 --follow --format='%H %cI %s' -- <doc>
```

- **No output** → the doc is untracked or was never committed. No baseline to diff against — skip it, record it as skipped in the final report, and say why.
- **That commit is HEAD**, or the range in step 3 comes back empty → nothing has landed since the doc was last touched. Report it as current; don't open a review pass.

## 3. Build the commit range since

List every commit since the doc's last edit, and the files each one touched, excluding the doc itself so its own edit history never counts as drift against itself:

```
git log <sha>..HEAD --format='%h %s' --name-only -- . ':!<doc>'
```

If the range is large — a long-neglected doc with dozens or hundreds of commits behind it — process it in full anyway. Don't truncate silently; note the size in the report, since this doc carries the most risk.

## 4. Judge relevance from commit messages first

Read the commit messages in the range and judge, per commit, whether it plausibly touches something the doc describes. The message is the cheapest signal and usually decides it — a `chore(deps)` bump next to an API-reference doc is obviously irrelevant; a `feat(auth):` commit next to an auth guide obviously isn't.

Only when a message is too vague to judge, pull the diff:

```
git show <sha>
```

This is deliberately not scoped by path — a commit that never touches the doc's own directory can still make it wrong (a renamed function, a deleted flag, a changed default). Judgement, not path proximity, decides relevance. This is an expensive, deliberate command the user runs by hand; the token cost of reading diffs is accepted.

If every commit in the range is judged irrelevant, report the doc as current and stop — no review pass, no edit.

## 5. Review and repair — one doc, one subagent

If any commit is plausibly relevant, delegate a full review-and-repair pass for that doc to **documentation-specialist**. Give it: the doc's full path, the last-edit sha, and the commits judged relevant (with their diffs already pulled if you fetched them in step 4).

The subagent's job, per doc:
1. Read the doc in full.
2. Read the diffs of the relevant commits.
3. Reconcile: statements now false, documented behaviour that changed, renamed/moved/deleted things still referenced, new behaviour that belongs in the doc but is missing.
4. Make the minimum edit that restores accuracy. Do not rewrite, restructure, or improve prose that is still correct — preserve the doc's existing voice and structure.
5. Report back, plainly: what was checked, what changed, and anything suspected but not verifiable from the diff alone.

Never review two docs in the same subagent call, and never let a subagent edit a doc without having read it in full first.

## 6. Batch subagents, never more than 2 in parallel

Hard limit: no more than 2 documentation-specialist subagents running at once. Queue the rest in sequential batches of 2. A repo with 40 docs needing review is 20 batches — say so up front rather than implying this is cheap or instant.

## 7. Commit each repaired doc

Docs-only commits, never mixed with code changes. Delegate to **git-specialist**:
- 1–3 files ideal, 5 is the soft cap — batch related doc fixes together (e.g. two docs touched by the same renamed API) if it stays under the cap; otherwise one commit per doc.
- Never push, never open a PR, never amend or rebase existing history. Commit locally and stop — the user pushes.

## 8. Report

End with a per-file table: doc path, last-edit date, commit count in range, verdict (`current` / `updated` / `skipped`), and what changed or why it was skipped. This is the deliverable even for docs that needed no change — "checked, found current" is a result, not a non-event.

# Resuming a plan

Follow these steps when a plan file for the current work has incomplete stages.

1. Read the plan file in full, including the Log.
2. For each stage marked `done`, verify its commit exists: `git cat-file -e <sha>`. If the commit is missing, mark the stage `pending` — do not trust the recorded status alone.
3. For each stage marked `running`, run `git status` and check for uncommitted changes that match that stage's scope. If found, report them to the user and wait — do not discard them, and do not mark the stage done or pending yourself.
4. Continue from the first stage that is not `done` with a valid commit.
5. Never redo a stage that is `done` with a commit confirmed present in step 2.
6. Append a log line: `<ISO time> resumed <first stage resumed from>`.

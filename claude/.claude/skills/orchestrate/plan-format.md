# Plan file format

One plan file per piece of work, at `<project root>/.plans/<plan-name>.md`.

```
# Plan: <name>
Goal: <one line>
Unattended: yes | no
Checkpoints: after phase <n>, ... | none
Re-brief limit: <n>

## Phase <n>: <name>
### Module: <name>
- RED       status: pending | running | done | bailed   commit: <sha>   re-briefs: <n>
- GREEN     status: ...                                  commit: <sha>   re-briefs: <n>
### Refactor review   status: ...   commit: <sha>

## Log
- <ISO time> <stage or event> <result>
```

## Field rules

- One plan file per piece of work. Do not fold unrelated work into an existing plan file.
- A stage's `status` changes only after the event happens — mark `running` when a worker starts, `done` or `bailed` only after its report comes back.
- Fill `commit` right after the commit for that stage lands. Leave it blank until then.
- `re-briefs` counts corrected briefs sent after a bail for that stage, capped by the plan's re-brief limit.
- CHORE stages do not need the RED/GREEN line shape — record a single line under the module, named for the chore, with the same status/commit fields.
- Briefs are not stored in the plan. Rebuild a brief from the plan file and the current code if a re-brief is needed.
- Append one line to the Log after every stage transition and after every commit. Keep log lines short: timestamp, stage or event name, result.

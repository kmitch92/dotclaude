---
name: shell
description: Shell scripting rules and preferences (bash/zsh). Workers read it when a task brief names this file.
disable-model-invocation: true
---

## Script header

- `#!/usr/bin/env bash` + `set -euo pipefail` on each script (exit on error, undefined variable, pipe failure).
- Set `IFS=$'\n\t'` to prevent word-splitting surprises.
- Resolve the directory of the script itself, if sibling files are necessary, rather than guessing the working directory of the caller.
- Trap cleanup on exit or error for a script that makes temp files or other state.

## Variables & quoting

- Constants: `UPPER_CASE`, `readonly`. Locals in functions use lowercase names and `local`.
- Always use quotation marks around variable expansions (`"$variable"`, `"${array[@]}"`).
- Use parameter expansion for defaults (`"${1:-default.txt}"`), rather than writing manual if-checks for this.

## Functions

- Condition-checking functions return a status (exit code), not a printed value.
- Check that required commands are there before you use them, and fail with a clear error if one is missing.

## User feedback

- Put info and warning messages to stdout or stderr, and always use the same method. Send errors to stderr, and exit with a non-zero code.
- Gate verbose/debug output behind a flag.
- Confirmation prompts default to "no" unless the step is safe to default to yes.

## Cross-platform

- Find the OS with `uname -s` (`Darwin*`/`Linux*`), and error out on an unsupported OS.
- Test scripts for macOS and Linux on each OS, and prevent flag differences that are only in GNU or only in BSD, for example `sed -i`.

## Idempotency

- Check state before you change it. Make a directory only if it is not there, and back up a file only if the next step overwrites it.
- Re-running a script must not fail or duplicate work.

## Argument parsing

- Parse flags with an explicit loop and `case`, and error on unknown flags.

## Shellcheck

- Each script must pass through `shellcheck script.sh` before it is done.
- Disable a rule only with a comment that explains why, and never blanket-disable a rule.

## Git hooks

- Pre-commit hooks run lint, typecheck, and the test suite, and fail loudly on a failing step.
- Post-merge hooks that install dependencies again must check the manifest file is there, and must not run without that check.

## Deployment scripts

- Write and test deployment scripts locally, in dry-run mode only.
- Never run a deployment directly, and give that job to the user instead.

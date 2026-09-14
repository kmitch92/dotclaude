---
name: shell
description: Shell scripting rules and preferences (bash/zsh). Read by workers when a task brief lists this file.
disable-model-invocation: true
---

## Script header

- `#!/usr/bin/env bash` + `set -euo pipefail` on every script (exit on error, undefined variable, pipe failure).
- Set `IFS=$'\n\t'` to avoid word-splitting surprises.
- Resolve the script's own directory when it needs sibling files, rather than assuming the caller's working directory.
- Trap cleanup on exit/error for any script that creates temp files or other state.

## Variables & quoting

- Constants: `UPPER_CASE`, `readonly`. Locals inside functions: lowercase, `local`.
- Always quote variable expansions (`"$variable"`, `"${array[@]}"`).
- Use parameter expansion for defaults (`"${1:-default.txt}"`) rather than manual if-checks.

## Functions

- Condition-checking functions return a status (exit code), not a printed value.
- Check required commands exist before using them; fail with a clear error if missing.

## User feedback

- Route info/warn to stdout/stderr consistently; errors to stderr, exit non-zero.
- Gate verbose/debug output behind a flag.
- Confirmation prompts default to "no" unless the action is safe to default to yes.

## Cross-platform

- Detect OS via `uname -s` (`Darwin*`/`Linux*`); error out on an unsupported OS.
- Scripts for both macOS and Linux must be tested on both, or avoid GNU-only/BSD-only flag differences (e.g. `sed -i`).

## Idempotency

- Check state before mutating it (only create a directory if missing, only back up a file about to be overwritten).
- Re-running a script must not fail or duplicate work.

## Argument parsing

- Parse flags with an explicit loop and `case`; error on unknown flags.

## Shellcheck

- Every script must pass `shellcheck script.sh` before it's done.
- Disable a rule only with a comment explaining why, never blanket-disable.

## Git hooks

- Pre-commit hooks run lint/typecheck/test and fail loudly on any failing step.
- Post-merge hooks that reinstall dependencies guard on the manifest file existing, not run unconditionally.

## Deployment scripts

- Write and test deployment scripts locally in dry-run mode only.
- Never execute a deployment directly — leave execution to the user.

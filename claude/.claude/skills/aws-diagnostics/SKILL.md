---
name: aws-diagnostics
description: AWS/cloud diagnostic rules and preferences — CLI-first debugging over UI. Read by workers when a task brief lists this file.
disable-model-invocation: true
---

## Prefer CLI/API over UI

- For any feature spanning services or infrastructure, diagnose via CLI/API calls, not by clicking through the product UI or a cloud console — console round-trips are slow and obscure the actual signal.
- Chain CLI/API calls together rather than checking one thing at a time; one script that pulls logs, DB state, and infra state in a single pass beats a sequence of manual console lookups.

## Diagnostic scripts

- Write a read-only diagnostic script (suffix `-diag.sh`) that goes straight to the source: tail logs, query state, describe infrastructure.
- Useful sources to chain: CloudWatch Logs tail, DynamoDB item/table state, ECS/ECR task and image state, SSM parameter state, Cognito user/pool state, API Gateway access logs.
- Keep these scripts read-only — no mutating AWS calls inside a diagnostic script.

## Driving behavior for verification

- Where safe, trigger the behavior under test via API mutations (the same calls that would cause the behavior in production) rather than clicking through the product UI, so the feedback loop is scriptable and repeatable.

## Structured logging

- Add structured logging at the key code seams involved in the diagnosis (target URL, auth outcome, status code, value received) so the diagnostic script's output is conclusive, not just suggestive.

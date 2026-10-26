---
name: aws-diagnostics
description: AWS/cloud diagnostic rules and preferences — CLI-first debugging above UI. Workers read it when a task brief names this file.
disable-model-invocation: true
---

## Prefer CLI/API over UI

- When a function touches some parts of the system or the infrastructure, find the problem through CLI or API calls.
- Do not click through the product UI or a cloud console to find it.
- Console round-trips are slow, and they hide the actual signal.
- Chain CLI or API calls together, rather than checking one thing at a time.
- One script that pulls logs, DB state, and infrastructure state in a single run beats a sequence of manual console lookups.

## Diagnostic scripts

- Write a read-only diagnostic script (suffix `-diag.sh`) that goes straight to the source: tail logs, query state, give infrastructure state.
- Useful sources to chain: CloudWatch Logs tail, DynamoDB item or table state, ECS or ECR task and image state, SSM parameter state, Cognito user or pool state, and API Gateway access logs.
- Keep these scripts read-only, and do not put mutating AWS calls in a diagnostic script.

## Driving behavior for verification

- Where safe, start the tested behavior through API mutations, since these are the same calls that cause the behavior in production.
- Do not click through the product UI to do this, so the feedback loop stays scriptable and repeatable.

## Structured logging

- Add structured logging at the key code seams in the diagnosis.
- Log the target URL, the auth outcome, the status code, and the value received.
- The output of the script becomes conclusive, not only suggestive.

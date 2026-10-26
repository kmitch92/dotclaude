---
name: aws-diagnostics
description: AWS/cloud diagnostic rules and preferences — CLI-first debugging above UI. Workers read it when a task brief names this file.
disable-model-invocation: true
---

## Prefer CLI/API over UI

- When a function touches some parts of the system or the infrastructure, find the problem through CLI or API calls.
- Do not click through the product UI or a cloud console to find it.
- Console round-trips are slow. They hide the actual signal.
- Chain CLI or API calls together. Do not check one thing at a time.
- One script that pulls logs, DB state, and infrastructure state in a single run is better.
- It beats a sequence of manual console lookups.

## Diagnostic scripts

- Write a read-only diagnostic script (suffix `-diag.sh`) that goes straight to the source: tail logs, query state, give infrastructure state.
- Useful sources to chain: CloudWatch Logs tail and DynamoDB item or table state.
- More useful sources: ECS or ECR task and image state, and SSM parameter state.
- More useful sources: Cognito user or pool state and API Gateway access logs.
- Keep these scripts read-only. Do not put mutating AWS calls in a diagnostic script.

## Driving behavior for verification

- Where safe, start the tested behavior through API mutations. These are the same calls that cause the behavior in production.
- Do not click through the product UI to do this.
- The feedback loop stays scriptable and repeatable.

## Structured logging

- Add structured logging at the key code seams in the diagnosis.
- Log the target URL, the auth outcome, the status code, and the value received.
- The output of the script becomes conclusive, not only suggestive.

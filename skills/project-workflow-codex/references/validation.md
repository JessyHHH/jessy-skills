# Validation

Codex validates process, artifacts, and outcome.

Required evidence:

```text
discovery record
clarity record
Phase 1 user confirmations
contract version(s)
preflight verdict
Claude Review Gate result
Codex replan/triage
Claude result
final audit
```

If a state lacks evidence, stop at the last verified state and report PASS_WITH_RISK or FAIL.

If Phase 1 lacks user confirmations, stop with:

```text
Phase: 1
Status: WAITING_FOR_USER_CONFIRMATION
Next allowed state: ask the next one-at-a-time clarification question
```

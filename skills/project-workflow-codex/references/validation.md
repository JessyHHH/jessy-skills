# Codex Workflow Validation

Use this before any completion claim.

## Required Evidence

- `git status --short`
- `git diff --stat`
- `git diff --check`
- Relevant project tests, usually `bash tests/test-*.sh` in this repository
- Plan-specific semantic checks

## Failure Handling

- If verification fails, fix and rerun the failed check.
- If a check cannot run because a tool is missing, record the missing tool and whether the rest of the evidence is enough for `PASS_WITH_RISK`.
- If changed files exceed the plan, either justify the drift or mark final audit `FAIL`.

## Final Verdicts

- `PASS`: scope matches, checks pass, no material unresolved risk.
- `PASS_WITH_RISK`: user goal likely satisfied, but a named check could not run or a documented low-risk drift remains.
- `FAIL`: required behavior is unverified, scope drift is unresolved, or checks fail.

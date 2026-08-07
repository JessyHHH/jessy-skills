# Codex Workflow Validation

Use this before any completion claim.

## Required Evidence

- `git status --short`
- `git diff --stat`
- `git diff --check`
- Relevant project tests, usually `bash tests/test-*.sh` in this repository
- Plan-specific semantic checks
- For repositories with an existing Graphify graph and accepted code changes:
  the post-verification `graphify update .` result, `graph_stats`, one relevant
  node or relationship, and a matching filesystem check

## Failure Handling

- If verification fails, fix and rerun the failed check.
- If a check cannot run because a tool is missing, record the missing tool and whether the rest of the evidence is enough for `PASS_WITH_RISK`.
- If changed files exceed the plan, either justify the drift or mark final audit `FAIL`.
- If the post-verification Graphify refresh fails, record the graph as stale and
  use `PASS_WITH_RISK`; use `FAIL` when the project contract requires a current graph.

## Final Verdicts

- `PASS`: scope matches, checks pass, no material unresolved risk.
- `PASS_WITH_RISK`: user goal likely satisfied, but a named check could not run or a documented low-risk drift remains.
- `FAIL`: required behavior is unverified, scope drift is unresolved, or checks fail.

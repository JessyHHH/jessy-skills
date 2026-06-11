# Codex Agent Execution

Use Codex agents as the execution plane for `project-workflow-codex`.

## Spawn Rules

- Spawn agents only after Phase 3 preflight passes.
- Keep the main agent on the critical path: routing, integration, state updates, and final audit stay local.
- Give every agent a bounded ownership set. Prefer disjoint write sets.
- Tell every agent that other edits may exist and must not be reverted.
- Require a structured result: changed files, commands run, evidence, open risks.

## Role Map

| Need | Agent role |
| --- | --- |
| Implement a bounded patch | `executor` or `worker` |
| Review diff against plan | `code-reviewer` |
| Validate claims and evidence | `verifier` |
| Improve tests | `test-engineer` |
| Diagnose failing checks | `debugger` or `build-fixer` |

## Prompt Contract

Every execution prompt should include:

```text
You own: <files/directories>
Do not edit: <forbidden files/directories>
Read first: <plan path>, <relevant docs>
Task: <specific outcome>
Constraints: preserve unrelated dirty worktree changes; do not revert others.
Return:
  - changed_files
  - commands_run
  - evidence
  - risks_or_blockers
```

## Integration Rules

- Inspect agent changes before claiming success.
- Re-run verification locally when feasible.
- If two agents touch overlapping files, the main agent resolves the overlap and reruns checks.
- "Agent completed" is not evidence. Evidence is file content, diff, command output, or reproducible behavior.

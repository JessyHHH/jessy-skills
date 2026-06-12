# Codex Agent Execution

Use Codex agents as the execution plane for `project-workflow-codex`.

This workflow uses native Codex agents from `~/.codex/agents/`. The repository
templates live in `codex/agents/` and are installed by `install.sh`. Hooks, OMX,
and oh-my-codex are not part of the execution path.

## Spawn Rules

- Spawn agents only after Phase 3 preflight passes.
- Keep the main agent on the critical path: routing, integration, state updates, and final audit stay local.
- Give every agent a bounded ownership set. Prefer disjoint write sets.
- Tell every agent that other edits may exist and must not be reverted.
- Require a structured result: changed files, commands run, evidence, open risks.

## Role Map

| Need | Agent role | Model |
| --- | --- | --- |
| Implement a bounded patch | `executor` or `worker` | `gpt-5.3-codex` |
| Improve or assess tests | `test-engineer` | `gpt-5.3-codex` |
| Fix build, lint, typecheck, or toolchain failures | `build-fixer` | `gpt-5.3-codex` |
| Diagnose failing checks or reproductions | `debugger` | `gpt-5.3-codex` |
| Review diff against plan | `code-reviewer` | `gpt-5.4-mini` |
| Validate claims and evidence | `verifier` | `gpt-5.4-mini` |

The main Codex session model is configured outside the agent templates and is
expected to be `gpt-5.5` for this repository workflow.

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

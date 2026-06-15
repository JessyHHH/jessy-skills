# Codex Subagent Execution

Use Codex subagents as the execution plane for `project-workflow-codex`.

This workflow uses native Codex subagent workflows and custom agents from
`~/.codex/agents/`. The repository templates live in `codex/agents/` and are
installed by `install.sh`. Hooks, OMX, and oh-my-codex are not part of the
execution path.

## Spawn Rules

- Spawn subagents only after Phase 3 preflight passes.
- Spawn subagents only when the task explicitly asks for delegation or the plan
  explicitly authorizes Phase 4 subagent work.
- Keep the main agent on the critical path: routing, integration, state updates, and final audit stay local.
- Prefer subagents for read-heavy work first: exploration, tests, triage, log
  analysis, and summarization.
- Use one writer subagent by default for implementation.
- Use multiple writer subagents only when each has a disjoint write set.
- Give every subagent a bounded ownership set. Prefer disjoint write sets.
- Tell every subagent that other edits may exist and must not be reverted.
- Require a structured result: changed files, commands run, evidence, open risks.
- Close completed subagent threads when their results are integrated so they do
  not keep consuming the open-thread cap.

## Role Map

| Need | Agent role | Model |
| --- | --- | --- |
| Read-heavy exploration | `explorer` | inherited / `gpt-5.4-mini` |
| Implement a bounded patch | `executor` or `worker` | `gpt-5.3-codex` |
| Improve or assess tests | `test-engineer` | `gpt-5.3-codex` |
| Fix build, lint, typecheck, or toolchain failures | `build-fixer` | `gpt-5.3-codex` |
| Diagnose failing checks or reproductions | `debugger` | `gpt-5.3-codex` |
| Review diff against plan | `code-reviewer` | `gpt-5.4-mini` |
| Validate claims and evidence | `verifier` | `gpt-5.4-mini` |

The main Codex session model is configured outside the agent templates and is
expected to be `gpt-5.5` for this repository workflow.

## Runtime Controls

- Set an expected first update window in the plan or prompt for each subagent.
- If a subagent is idle beyond that window, inspect it with `/agent` when
  available.
- Send one steering prompt with the exact next command, file, or output needed.
- If the subagent remains idle after the steering prompt, stop or close it and
  record `BLOCKED_AGENT` with the agent name, owned scope, and last observed
  state.
- Do not let the main session silently take over implementation after a stuck
  subagent. Either respawn with a narrower scope or ask the user before main
  performs code edits outside integration and verification.
- Keep `agents.max_depth = 1` unless recursive delegation is explicitly needed.
  Broad recursive delegation increases latency, token usage, and coordination
  risk.

## Prompt Contract

Every execution prompt should include:

```text
You own: <files/directories>
Do not edit: <forbidden files/directories>
Read first: <plan path>, <relevant docs>
Task: <specific outcome>
Constraints: preserve unrelated dirty worktree changes; do not revert others.
First update window: <duration or milestone>
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

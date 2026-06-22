---
name: project-workflow-codex
description: "Run the Codex-only project workflow: detect context, design, plan, execute with Codex subagents, review, verify, and finish using .codex state and fresh evidence."
---

# Project Workflow Codex

Use this as the Codex-only workflow entry point. This branch does not support Claude Code or Hermes workflows; switch branches for those tools.

## Control Model

Codex main owns routing, state, integration, and final claims. Codex subagents own bounded exploration, implementation, review, test, repair, or verification tasks.

Use Codex subagents deliberately:

- Spawn Codex subagents only for explicitly bounded work.
- Prefer parallel subagents for read-heavy work.
- Allow parallel writers only when file sets are disjoint.
- Use `/agent` to inspect, steer, stop, or close subagent threads.
- Record `BLOCKED_AGENT` evidence when a subagent stalls after inspection and one steering prompt.
- Do not treat subagent completion as evidence. Verify locally before claiming completion.

Read `references/agent-execution.md` before spawning subagents. Read `references/validation.md` before final claims.

## State

Use `.codex/state/project-workflow-state.json` as the durable baton.

Minimum state:

```json
{
  "workflow": "project-workflow-codex",
  "version": "v1",
  "runMode": "full-workflow",
  "handoffPolicy": "auto-continue",
  "currentSkill": "detecting-environment",
  "lastCompletedSkill": null,
  "nextSkill": "designing-solutions",
  "status": "running",
  "taskIntakePath": ".codex/state/task-intake.json",
  "contextSummaryPath": null,
  "grillEvidencePath": null,
  "specPath": null,
  "planPath": null,
  "quickGateResultsPath": null,
  "reviewResultsPath": null,
  "verificationResultsPath": null,
  "escapeHatchesUsed": []
}
```

Artifacts:

- Root context: `CONTEXT.md`
- Codex instructions: `AGENTS.md`
- Knowledge cache: `.codex/context/knowledge.md`
- Specs: `.codex/specs/`
- Plans: `.codex/plans/`
- Runtime state: `.codex/state/`

## Execution Skills

Route in this order:

1. `detecting-environment` - Phase 0, 0.3, 0.5.
2. `designing-solutions` - Phase 1, requirement echo and grill.
3. `planning-implementation` - Phase 2 and 3.
4. `implementing-changes` - Phase 4, 4.5, 4.6.
5. `reviewing-implementation` - Phase 5.
6. `verifying-completion` - Phase 6.
7. `finishing-development` - Phase 7 and 8.

The entry skill does not implement these phases inline. It initializes state, invokes or reads the next execution skill, and checks that the previous skill wrote its required artifact before transitioning.

## Discovery Budget

Codex startup discovery should expose only:

- `project-workflow-codex`
- `karpathy-guidelines`

The full skill snapshot remains under `~/.jessy-skills-codex/skills`. Load execution and domain skills explicitly from that snapshot or this repository after routing confirms relevance.

## Start Or Resume

1. Read `.codex/state/project-workflow-state.json`.
2. If it is running, continue with `currentSkill`.
3. If it is complete, ask whether to restart.
4. If missing, create the minimum state above and continue to `detecting-environment`.
5. Announce the selected skill and why it is next.

## Direct Routing

If the user asks for a specific phase, set `runMode="standalone-skill"` and `handoffPolicy="prompt-next-step"`, then route:

| User intent | Skill |
| --- | --- |
| detect, inspect, setup context | `detecting-environment` |
| design, clarify, grill, spec | `designing-solutions` |
| plan, tasks, consensus | `planning-implementation` |
| implement, build, fix | `implementing-changes` |
| review, audit | `reviewing-implementation` |
| verify, test, prove completion | `verifying-completion` |
| finish, commit, PR, branch cleanup | `finishing-development` |

## Escape Hatches

- `quick` / `fast` - reduce interview or review depth, keep verification.
- `deep` / `careful` - use deeper review and verification.
- `skip design` - proceed to planning from task intake only.
- `skip plan` - execute only when tasks are already explicit.
- `no review` - skip Phase 5 only after warning the user.
- `I'll test` - skip Phase 6 only when the user owns verification.
- `skip branch` - skip branch finish actions.

Record escape hatches in state.

## Anti-Patterns

- Do not use Claude Code `Workflow(...)` scripts.
- Do not use Claude `CLAUDE.md` or `.claude/` paths.
- Do not use Hermes `project-workflow`.
- Do not load every skill at startup.
- Do not let subagents edit overlapping files in parallel.
- Do not claim completion without fresh verification.

## Final Audit

Before final response:

- `git status --short`
- `git diff --stat`
- `git diff --check`
- relevant tests from the plan
- semantic evidence checks from the plan

Final verdicts: `PASS`, `PASS_WITH_RISK`, or `FAIL`.

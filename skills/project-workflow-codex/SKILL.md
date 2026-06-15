---
name: project-workflow-codex
description: "Run the Codex project workflow: discover repo, route skills, plan, delegate to Codex subagents, review, and verify with fresh evidence."
---

# Project Workflow Codex

## Overview

Run the jessy-skills development workflow in Codex using skills plus Codex subagents. This is the Codex-native branch of the Claude Code `Workflow(...) + Skill(...)` design: the control plane stays in the main Codex session, while execution is delegated to Codex subagents with explicit ownership, artifacts, watchdogs, and verification.

Core rule:

```text
Codex main agent owns routing, state, phase transitions, and final claims.
Codex subagents own bounded exploration, execution, review, or verification tasks.
Do not invoke Claude Code Workflow scripts from this skill.
Do not rely on hooks, OMX, or oh-my-codex.
Do not trust subagent success reports without independent verification.
```

Model routing:

```text
Main Codex session: configured outside this skill, recommended gpt-5.5.
Execution, test, repair, and debugging subagents: executor, worker, test-engineer, build-fixer, debugger -> gpt-5.3-codex.
Review and plan/completion verification subagents: code-reviewer, verifier -> gpt-5.4-mini.
```

## State Files

Use `.codex/state/project-workflow-state.json` as the durable baton. Save plan contracts under `.codex/plans/` and verification artifacts under `.codex/state/`.

Minimum state fields:

```json
{
  "workflow": "project-workflow-codex",
  "version": "v0.1",
  "currentPhase": "0",
  "status": "running",
  "baseCommit": null,
  "planPath": null,
  "agentResultsPath": null,
  "verificationResultsPath": null
}
```

Every phase must finish with:

```text
Phase: <phase>
Status: COMPLETE | WAITING_FOR_USER | BLOCKED | FAIL
Evidence:
  - <file/command/result>
Next:
  - <allowed next phase>
```

## Skill Discovery Budget

Codex startup should expose only entry skills such as `project-workflow-codex`
and `karpathy-guidelines`. Full domain skills stay in the installed snapshot
under `~/.jessy-skills-codex/skills` and should be loaded by explicit path only
after routing confirms they are relevant. Do not require all repository skills
to be present in the model-visible startup skills list.

## Phase 0: Discovery

Read and record:

```text
git branch --show-current
git status --short
git rev-parse HEAD
AGENTS.md
CLAUDE.md if present
README.md / SETUP.md / install.sh when relevant
skills/project-workflow-codex/SKILL.md
skills/project-workflow-claude/SKILL.md only for compatibility questions
~/.jessy-skills-codex/skills when checking installed domain skill inventory
```

Never revert unrelated user changes. If the worktree is dirty, list dirty files and decide whether they are in scope before editing.

## Phase 0.3: Knowledge

If `.codex/context/knowledge.md` is missing or stale for `HEAD`, create or refresh it with:

```text
Commit
Project type
Skill inventory summary
Workflow entry points
Test/verification commands
Known risks and invariants
```

Keep `AGENTS.md` short. Long process details belong in this skill or `references/`.

## Phase 0.5: Skill Routing

Always include:

```text
Codex: project-workflow-codex, karpathy-guidelines
```

Add domain skills only when task signals justify them. If a routed domain skill
is absent from the startup skill list, read it from `~/.jessy-skills-codex/skills/<skill>/SKILL.md`
or the repository `skills/<skill>/SKILL.md`. Read `references/agent-execution.md`
before spawning agents and `references/validation.md` before final claims.

## Phase 1: Clarify

Clarify only the boundaries that cannot be safely inferred:

```text
goal
scope and non-goals
expected changed files
forbidden changes
verification requirements
approval boundary for spawning agents
```

Ask one concise question at a time when clarification is required. If the request is already specific, record assumptions and proceed.

## Phase 2: Plan Contract

Write `.codex/plans/YYYY-MM-DD_HHMMSS-codex-plan-<slug>.md` with:

```text
Metadata
Discovery evidence
Skill routing
Scope and non-goals
Tasks with owner role, files, expected changes, forbidden changes
Agent execution map
Verification contract
Rollback / no-revert constraints
Final audit checklist
```

Use `references/contract-template.md` as the shape.

## Phase 3: Codex Preflight

Before execution, verify:

```text
baseCommit matches HEAD or drift is documented
expected and forbidden files are explicit
each task has a disjoint write set where possible
verification commands are runnable or skipped with reason
subagent roles are bounded
```

Verdict must be `PASS`, `PASS_WITH_RISK`, or `FAIL`. Do not spawn implementation subagents on `FAIL`.

## Phase 4: Codex Subagent Execution

Spawn Codex subagents only for bounded tasks with clear ownership. Prefer:

```text
explorer: read-heavy codebase exploration, risk discovery, or context gathering
executor / worker: implementation
build-fixer / debugger: failing build, lint, typecheck, or reproduction diagnosis
code-reviewer: independent review
verifier: completion evidence
test-engineer: focused test coverage
```

Use subagents deliberately:

```text
Codex does not spawn subagents automatically.
Prompt explicitly when parallel subagent work is intended.
Prefer parallel subagents for read-heavy work: exploration, tests, triage, log analysis, and summarization.
Default to one writer subagent for implementation.
Allow multiple writer subagents only when write sets are disjoint and named in the plan.
Keep agents.max_depth at 1 unless recursive delegation is explicitly required.
```

Each subagent prompt must include:

```text
plan path
owned files or directories
forbidden files
expected output shape
instruction to preserve unrelated changes
instruction to list changed files and verification run
instruction to return progress or a blocker instead of waiting silently
```

Runtime watchdog:

```text
If a subagent has no visible progress for the expected first update window:
1. Inspect the subagent thread with `/agent` when available.
2. Send one steering prompt with the exact next action and requested output.
3. If it remains idle, stop or close that subagent and record BLOCKED_AGENT evidence.
4. Respawn with a narrower read-only or single-file scope, or ask the user before the main session takes over implementation.
```

The main agent integrates results, resolves conflicts, closes completed subagent threads when no longer needed, and performs direct verification. See `references/agent-execution.md`.

## Phase 5: Review

Run review after implementation:

```text
spec compliance first
code quality second
verification adequacy third
```

For small changes, the main agent may review directly. For broader changes, spawn a `code-reviewer` subagent with the plan path and diff, then independently validate findings before acting on them.

## Phase 6: Verify

Run fresh verification commands from the plan. At minimum:

```text
git diff --check
bash tests/test-*.sh
```

If a command cannot run, record the exact reason. Do not claim completion from subagent reports alone.

## Final Audit

Before final response:

```text
git status --short
git diff --stat
compare changed files against plan
compare behavior against user request
summarize verification evidence
```

Final verdict: `PASS`, `PASS_WITH_RISK`, or `FAIL`.

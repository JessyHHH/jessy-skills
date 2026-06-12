---
name: project-workflow-codex
description: "Use when Codex should run the project workflow with Codex agents instead of Claude Code Workflow scripts: discover the repo, route skills, clarify scope, write a plan contract, spawn Codex executor/reviewer/verifier agents for implementation, and perform final audit with fresh evidence."
---

# Project Workflow Codex

## Overview

Run the jessy-skills development workflow in Codex using skills plus Codex agents. This is the Codex-native branch of the Claude Code `Workflow(...) + Skill(...)` design: the control plane stays in the main Codex session, while execution is delegated to Codex agents with explicit ownership, artifacts, and verification.

Core rule:

```text
Codex main agent owns routing, state, phase transitions, and final claims.
Codex agents own bounded execution, review, or verification tasks.
Do not invoke Claude Code Workflow scripts from this skill.
Do not rely on hooks, OMX, or oh-my-codex.
Do not trust agent success reports without independent verification.
```

Model routing:

```text
Main Codex session: configured outside this skill, recommended gpt-5.5.
Execution, test, repair, and debugging agents: executor, worker, test-engineer, build-fixer, debugger -> gpt-5.3-codex.
Review and plan/completion verification agents: code-reviewer, verifier -> gpt-5.4-mini.
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

Add domain skills only when task signals justify them. Read `references/agent-execution.md` before spawning agents and `references/validation.md` before final claims.

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
agent roles are bounded
```

Verdict must be `PASS`, `PASS_WITH_RISK`, or `FAIL`. Do not spawn implementation agents on `FAIL`.

## Phase 4: Codex Agent Execution

Spawn Codex agents only for bounded tasks with clear ownership. Prefer:

```text
executor / worker: implementation
build-fixer / debugger: failing build, lint, typecheck, or reproduction diagnosis
code-reviewer: independent review
verifier: completion evidence
test-engineer: focused test coverage
```

Each agent prompt must include:

```text
plan path
owned files or directories
forbidden files
expected output shape
instruction to preserve unrelated changes
instruction to list changed files and verification run
```

The main agent integrates results, resolves conflicts, and performs direct verification. See `references/agent-execution.md`.

## Phase 5: Review

Run review after implementation:

```text
spec compliance first
code quality second
verification adequacy third
```

For small changes, the main agent may review directly. For broader changes, spawn a `code-reviewer` agent with the plan path and diff, then independently validate findings before acting on them.

## Phase 6: Verify

Run fresh verification commands from the plan. At minimum:

```text
git diff --check
bash tests/test-*.sh
```

If a command cannot run, record the exact reason. Do not claim completion from agent reports alone.

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

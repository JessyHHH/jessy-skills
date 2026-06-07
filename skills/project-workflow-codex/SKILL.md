---
name: project-workflow-codex
description: "Use when Codex should plan a development task before execution: run discovery, bootstrap AGENTS.md/knowledge, route skills, generate a Cross-Agent Plan Contract for Claude Code, triage Claude Phase 3 review, replan, and final-audit execution."
version: "v0.1"
author: "jessyhuang"
---

# Project Workflow Codex

Use this skill when Codex is the planner/auditor and Claude Code is the executor.

Core rule:

```text
Codex owns Phase 0-3 planning and final audit.
Claude Code owns contract review and Phase 4-6 execution.
Codex must not treat Claude's success message as proof; verify evidence.
```

## Phase 0: Discovery

Read before planning:

```text
git branch --show-current
git status --short
git rev-parse HEAD
README.md / SETUP.md / install.sh when relevant
AGENTS.md when present
CLAUDE.md when present
skills/project-workflow-claude/SKILL.md when Claude execution is involved
```

Record:

```text
project_root
current_branch
base_commit
dirty_files
files_read
commands_run
relevant_workflows
risks
```

Never revert user changes.

## Phase 0.3: Knowledge + AGENTS.md Bootstrap

If `.codex/context/knowledge.md` is missing or stale, generate a concise project knowledge file with commit SHA and project type.

For `AGENTS.md`:

```text
If missing:
  create a short repo-level AGENTS.md scaffold.

If present:
  preserve human-written content.
  update only explicit AUTO blocks if they exist.

In the current session:
  read AGENTS.md after creating/updating it.
```

Do not bloat `AGENTS.md`. Put long workflow details in `codex/` docs or skills references.

## Phase 0.5: Skill Routing

Choose Codex planner skills and recommended Claude executor skills.

Always include:

```text
Codex:
  project-workflow-codex
  karpathy-guidelines

Claude Code:
  project-workflow-claude
  karpathy-guidelines
```

Add domain skills only when task signals justify them, for example Go, Vue, frontend, database, testing, code review, TDD, diagnosis, or skill creation.

The contract must include a `Skill Routing` section and task-level `recommendedSkills` when useful.

## Phase 1: Clarify

Before writing a contract, establish:

```text
goal
in_scope
out_of_scope
assumptions
acceptance_criteria
user_approval_needed
```

Ask only when local evidence cannot resolve a risky ambiguity.

## Phase 2: Generate Contract

Generate a Cross-Agent Plan Contract for Claude Code.

Required sections:

```text
Metadata
Phase 0 Discovery
Phase 0.3 Knowledge + AGENTS.md
Phase 0.5 Skill Routing
Phase 1 Clarity
Phase 2 Plan
Tasks as JSON
Verification Contract
Claude Phase 3 Review Requirements
Codex Replan Requirements
Executor Instructions
Required Claude Result Shape
```

For a real execution handoff, save the contract to:

```text
.claude/plans/YYYY-MM-DD_HHMMSS-codex-contract-v<N>-<slug>.md
```

## Phase 3: Codex Preflight

Before giving the contract to Claude Code, verify:

```text
base_commit matches HEAD or drift is documented
goal/non-goals are clear
expected_changed_files and forbidden_changes are present
every task is self-contained
every task has files and verification
Skill Routing is present
Claude Phase 3 instructions are present
user execution approval gate is present
```

Verdict:

```text
PASS
PASS_WITH_RISK
FAIL
```

Only PASS, or user-accepted PASS_WITH_RISK, can go to Claude Code.

## Claude Phase 3 Review

Ask Claude Code to review only. It must not implement yet.

Required review shape:

```text
verdict: APPROVE | ITERATE | REJECT
findings:
  - id
  - severity
  - section
  - issue
  - why_it_matters
  - suggested_contract_change
missing_questions
execution_risks
approval_conditions
```

## Phase 3.5: Codex Replan

Triage every Claude finding:

```text
ACCEPT: improves correctness, scope clarity, verification, or execution safety
DEFER: useful but not required for this task
REJECT: expands scope, conflicts with user intent, or lacks evidence
```

If Claude returns ITERATE, produce a new contract version and run preflight again.

If Claude returns REJECT, return to the phase that failed: discovery, clarify, or plan.

If Claude returns APPROVE, still inspect findings. Do not proceed with unresolved critical/high findings.

## Execution Gate

Claude Code may enter Phase 4 only when:

```text
contract status = APPROVED_FOR_EXECUTION
Claude Phase 3 verdict = APPROVE
Codex triage is complete
user approved execution
```

## Final Audit

After Claude Code completes Phase 4-6, Codex runs final audit:

```text
read Claude result
git status --short
git diff --stat
git diff
git diff --check
rerun contract verification commands when feasible
compare changed files against expected/forbidden files
compare result against original user request
```

Final verdict:

```text
PASS
PASS_WITH_RISK
FAIL
```

Report the verdict with evidence. Do not claim DONE without Codex final audit.


---
name: project-workflow-codex
description: "Use when Codex should plan a development task before execution: run discovery, bootstrap AGENTS.md/knowledge, route skills, ask one-at-a-time user clarification questions, generate a Cross-Agent Plan Contract for Claude Code, triage Claude review, replan, and final-audit execution."
version: "v0.2"
author: "jessyhuang"
---

# Project Workflow Codex

Use this skill when Codex is the planner/auditor and Claude Code is the executor.

Core rule:

```text
Codex owns Phase 0-3 planning and final audit.
Codex Phase 3 means Codex Contract Preflight only.
Claude Code owns the Claude Review Gate and Phase 4-6 execution.
Codex must not treat Claude's success message as proof; verify evidence.
```

## Observable Phase Gates

Every phase must end with a visible status block:

```text
Phase: <0 | 0.3 | 0.5 | 1 | 2 | 3 | 3.5 | final-audit>
Status: COMPLETE | WAITING_FOR_USER_CONFIRMATION | BLOCKED | FAIL
Evidence:
  - ...
Next allowed state:
  - ...
```

Do not silently advance phases. If evidence is missing, stop at the last verified phase and say what is needed next.

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

## Phase 1: Clarify User Boundaries

Phase 1 is an interactive hard gate. Codex must clarify with the user before writing a ready contract.

Required clarity dimensions:

```text
goal
scope_boundary
architecture_or_layout_choices
constraints_and_non_goals
acceptance_criteria
execution_approval_boundary
```

Question protocol:

```text
Ask exactly one question per assistant turn.
Prefer A/B/C/D options.
Make option A the recommended option when there is a clear recommendation.
Label it "(Recommended)" and include the reason in one short sentence.
Make the final option a custom/manual option when useful.
After the user answers, record the selected answer in the clarity packet.
Continue until all required clarity dimensions are confirmed.
```

Do not self-fill Phase 1 from local evidence alone. Local evidence can shape the recommended answer, but user-facing boundary choices still need user confirmation.

Phase 1 may only complete when the user has confirmed the clarity packet.

If the user has not confirmed Phase 1:

```text
Status: WAITING_FOR_USER_CONFIRMATION
Contract status, if drafted: DRAFT_PENDING_USER_CLARIFICATION
Codex Phase 3 verdict: FAIL or NOT_VALID_YET
```

## Phase 2: Generate Contract

Generate a Cross-Agent Plan Contract for Claude Code only after Phase 1 is complete.

Required sections:

```text
Metadata
Phase 0 Discovery
Phase 0.3 Knowledge + AGENTS.md
Phase 0.5 Skill Routing
Phase 1 Clarity
Phase 1 User Confirmations
Phase 2 Plan
Tasks as JSON
Verification Contract
Claude Review Gate Requirements
Codex Replan Requirements
Executor Instructions
Required Claude Result Shape
```

For a real execution handoff, save the contract to:

```text
.claude/plans/YYYY-MM-DD_HHMMSS-codex-contract-v<N>-<slug>.md
```

If Phase 1 is still waiting on the user, a draft may be saved for discussion, but it must use:

```text
status: DRAFT_PENDING_USER_CLARIFICATION
```

## Phase 3: Codex Contract Preflight

Before giving the contract to Claude Code, verify:

```text
Phase 1 status is COMPLETE
base_commit matches HEAD or drift is documented
goal/non-goals are clear
expected_changed_files and forbidden_changes are present
every task is self-contained
every task has files and verification
Skill Routing is present
Claude Review Gate instructions are present
user execution approval gate is present
```

Verdict:

```text
PASS
PASS_WITH_RISK
FAIL
```

If Phase 1 is not complete, Phase 3 cannot PASS.

Only PASS, or user-accepted PASS_WITH_RISK, can go to Claude Code.

## Claude Review Gate

Ask Claude Code to review only. It must not implement yet.

Do not call this Codex Phase 3. Codex Phase 3 is the preflight above. The Claude Review Gate is the executor-side contract review before implementation.

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
Claude Review Gate verdict = APPROVE
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

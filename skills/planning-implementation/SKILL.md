---
name: planning-implementation
description: Convert an approved Codex design into a concrete implementation plan, validate task contracts, run consensus review, and prepare .codex plan artifacts.
---

# Planning Implementation

Use this for Codex Phase 2 and Phase 3.

## Inputs

- `.codex/state/task-intake.json`
- `.codex/state/context-summary.json`
- `.codex/state/grill-evidence.json` when present
- `.codex/specs/<design>.md` unless `skip design` was recorded

## Procedure

1. Validate state.
   - Required field: `contextSummaryPath`.
   - If both `specPath` and `grillEvidencePath` are missing and `skip design` is not recorded, block.

2. Read approved design and intake.

3. Write `.codex/plans/YYYY-MM-DD_HHMMSS-<slug>.md`.
   - Include goal, context, approach, files, verification, risks, and task JSON.
   - Use `references/task-schema.md` for task shape.

4. Validate task schema.
   - Unique `id`.
   - Self-contained prompt.
   - Exact `files`.
   - `complexity`.
   - Mutating tasks specify patch strategy.
   - Expected evidence or a verification explanation.

5. Run consensus review.
   - Use Codex subagents for independent architecture, risk, and feasibility review when the plan is non-trivial.
   - Wait for all reviewers, then synthesize.
   - Reject if scope contradicts `approvedOutOfScope`.
   - Reject if unresolved critical ambiguities remain.

6. Act on verdict.
   - `APPROVE`: ask user to approve the plan.
   - `ITERATE`: update plan and rerun review, max 3 iterations.
   - `REJECT`: stop with reasons.

## Exit

Update `.codex/state/project-workflow-state.json`:

- `lastCompletedSkill="planning-implementation"`
- `currentSkill="implementing-changes"`
- `nextSkill="reviewing-implementation"`
- `planPath=".codex/plans/<actual-file>.md"`

If `handoffPolicy=auto-continue`, continue to `implementing-changes`.

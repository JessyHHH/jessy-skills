---
name: reviewing-implementation
description: "Review implemented Codex workflow changes in the required order: spec compliance first, then code quality, then verification adequacy, using Codex reviewers when useful."
---

# Reviewing Implementation

Use this for Codex Phase 5.

## Inputs

- `.codex/state/project-workflow-state.json`
- `.codex/plans/<plan>.md`
- `.codex/state/phase4-execution-results.json`
- `.codex/state/quick-gate-results.json`
- `.codex/state/grill-evidence.json` when present
- Current git diff

## Procedure

1. Validate state.
   - Required field: `quickGateResultsPath`.
   - Block if missing.

2. Prepare context.
   - Read plan.
   - Compute changed files and relevant diffs.
   - Map diffs to tasks.
   - Include Phase 4 plan approvals, scope gates, diff evidence, quick gate concerns, and grill decisions.
   - Block when a writer task lacks `planApproved=true`, `scopeGate=PASS`, or captured diff evidence.

3. Fast gate.
   - `git diff --check`.
   - Check expected files exist.
   - Run narrow static checks when obvious.

4. Spec compliance review.
   - This runs before code quality.
   - Use `code-reviewer` subagents for non-trivial or multi-file tasks.
   - Block on missing required behavior or forbidden scope changes.

5. Code quality review.
   - Review correctness, safety, maintainability, and simplicity.
   - Focus on changed lines and integration points.

6. Verification adequacy review.
   - Confirm tests and semantic checks match the plan.
   - Missing evidence is a gap, not a pass.

7. Fix and retry.
   - Critical/spec failures return to `implementing-changes`.
   - Re-review after fixes, max 3 iterations before user escalation.

8. Persist `.codex/state/review-results.json`.

## Exit

Update `.codex/state/project-workflow-state.json`:

- `lastCompletedSkill="reviewing-implementation"`
- `currentSkill="verifying-completion"`
- `nextSkill="finishing-development"`
- `reviewResultsPath=".codex/state/review-results.json"`

If review passes and `handoffPolicy=auto-continue`, continue to `verifying-completion`.

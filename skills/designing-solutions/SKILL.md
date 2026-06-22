---
name: designing-solutions
description: Turn a Codex workflow request into confirmed requirements and an approved design spec using requirement echo, grill-me, ambiguity tracking, and .codex design artifacts.
---

# Designing Solutions

Use this for Codex Phase 1. Do not edit implementation files before the design is approved.

## Inputs

- `.codex/state/task-intake.json`
- `.codex/state/context-summary.json`
- User request and clarification answers
- `CONTEXT.md` and `.codex/context/knowledge.md`

## Procedure

1. Validate state.
   - Required field: `contextSummaryPath`.
   - Block if missing.

2. Explore first.
   - Read files that can answer factual questions.
   - Do not ask the user questions the repository can answer.

3. Requirement echo.
   - Restate extracted requirements with sources.
   - Ask whether the list is complete and correct before deeper design.

4. Grill with `grill-me`.
   - Use one forcing question at a time.
   - Provide a recommended answer with rationale.
   - Walk decision dependencies depth-first.
   - Maintain an Ambiguity Register and Assumption Ledger.
   - Stop when shared understanding is reached and the hard checklist passes.

5. Persist `.codex/state/grill-evidence.json`.

6. Propose approaches.
   - Present 2-3 viable approaches.
   - Recommend one with tradeoffs.

7. Write `.codex/specs/YYYY-MM-DD-<topic>-design.md`.
   - Use `references/design-spec-template.md` as the template.
   - Include scope, non-goals, decisions, verification, and risks.

8. Self-review the spec.
   - Remove placeholders.
   - Check internal consistency.
   - Ensure the scope is implementation-plan sized.

9. Ask for design approval.

## Exit

Update `.codex/state/project-workflow-state.json`:

- `lastCompletedSkill="designing-solutions"`
- `currentSkill="planning-implementation"`
- `nextSkill="implementing-changes"`
- `grillEvidencePath=".codex/state/grill-evidence.json"`
- `specPath=".codex/specs/<actual-file>.md"`

If `handoffPolicy=auto-continue`, continue to `planning-implementation`.

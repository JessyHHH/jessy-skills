# Next-Step Handoff Contract

Every execution skill supports two usage modes.

## Full Workflow Mode

If `.claude/state/project-workflow-state.json` has `handoffPolicy=auto-continue`, announce the next skill and invoke it after the exit gate passes.

Example:

```text
Environment/context setup complete.
→ Continuing full workflow: invoking /designing-solutions.
```

## Standalone Skill Mode

If invoked directly by the user, do not silently stop. Print what was completed, the saved outputs, and the recommended next skill.

Example:

```text
Design approved and saved to `.claude/specs/2026-06-10-example-design.md`.

Recommended next step:
1. /planning-implementation (Recommended) — create a concrete task plan and run consensus review.
2. Revise design — if scope or assumptions changed.
3. Stop here — keep design only.
```

## Handoff Table

| Current Skill | Recommended Next Step | Alternatives |
|---|---|---|
| `detecting-environment` | `/designing-solutions` | `/project-workflow-claude continue`, stop here |
| `designing-solutions` | `/planning-implementation` | revise design, stop here |
| `planning-implementation` | `/implementing-changes` | stop here, implement manually |
| `implementing-changes` | `/reviewing-implementation` | return to `/implementing-changes` if quick gate failed, `/verifying-completion` only if review explicitly skipped |
| `reviewing-implementation` | `/verifying-completion` | `/implementing-changes` if findings need fixes |
| `verifying-completion` | `/finishing-development` | stop here and keep branch as-is |
| `finishing-development` | done | no next skill |

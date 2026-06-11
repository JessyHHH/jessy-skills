---
name: planning-implementation
description: Use when an approved design or clear requirements must become a concrete implementation plan. Writes `.claude/plans/`, defines expanded json:tasks, runs consensus review with Workflow(name='phase3-consensus'), and hands off to implementing-changes in full-workflow mode.
version: "v2.7"
---

# Planning Implementation

## Purpose

Convert the approved design into a concrete implementation plan and validate it with consensus review before any file changes. Combines the legacy Phase 2 (write plan) and Phase 3 (consensus review) into a single modular skill.

## Inputs

- `.claude/state/task-intake.json` -- request summary, scope, constraints
- `.claude/state/context-summary.json` -- project type, context freshness, loaded skills
- `.claude/state/grill-evidence.json` -- ambiguity register + assumption ledger (may be null for simple tasks)
- `.claude/specs/<design>.md` -- approved design spec

## Procedure

### Step 0: State Validation

Read `.claude/state/project-workflow-state.json`.

Verify required fields per `skills/project-workflow-claude/references/state-validation.md`.

**Required for this phase:** `contextSummaryPath`

- If any required field is missing or null: BLOCK. Report exactly what's missing.
- If `escapeHatchesUsed` is missing from state file: default to `[]` (backward compat).
- If all required fields present: continue to Step 1.

After checking contextSummaryPath, check: if BOTH `specPath` AND `grillEvidencePath` are null AND `"skip design"` NOT in `escapeHatchesUsed` → BLOCK with: "No design spec found. Run /designing-solutions first, or say 'skip design' to proceed with task-intake.json only."

### Step 1: Read the Approved Design Spec

Read the design spec from `.claude/specs/<design>.md`. Extract:
- Scope boundary and requirements
- Recommended approach with architecture decisions
- File paths, module boundaries, key interfaces
- Verification strategy and success criteria

### Step 2: Write Implementation Plan

Delegate writing `.claude/plans/YYYY-MM-DD_HHMMSS-<slug>.md` to a subagent:

```
Agent(description='Write implementation plan',
  prompt='Write the implementation plan to .claude/plans/<timestamp>-<slug>.md with:
  1. Goal -- concise one-liner of what we are building
  2. Context -- version, project type, key decisions from design
  3. Approach -- step-by-step with exact file paths
  4. Files -- all files to create or modify, with expected changes
  5. Verification -- how we will test each step
  6. Risks -- known risks, tradeoffs, open questions
  7. Tasks -- a ```json:tasks fenced code block at the end with an array of task objects using the expanded task schema from references/task-schema.md',
  subagent_type='general-purpose')
```

The plan MUST include the `json:tasks` fenced code block.

### Step 3: Validate Task Schema

After the plan is written, validate each task in the `json:tasks` block against `references/task-schema.md`:

- Every task has a unique `id` (T1-short-name format).
- Every task has a self-contained `prompt` (subagent starts with blank context).
- Every task lists exact `files` paths.
- Every task has `complexity` (simple/medium/complex).
- Every mutating task has a `patchBackStrategy`.
- Every task has `expectedEvidence` or a verification explanation.

### Step 4: Collect Context for Consensus Review

Before invoking the consensus workflow, the master agent MUST collect:

1. **contextSummary**: From `.claude/state/context-summary.json` (projectType, knowledgeStatus, confirmedFacts, etc.)
2. **grillSummary**: From `.claude/state/grill-evidence.json` (ambiguityRegister + assumptionLedger). If the file does not exist (simple tasks may skip Grill), pass `null` and document the omission in contextWarnings.
3. **taskIntakeSnapshot**: From `.claude/state/task-intake.json`
4. **tasks**: Parsed tasks array from the plan's `json:tasks` block

These enable pre-check validation: scope contradiction detection, ambiguity resolution, and task contract validation.

### Step 5: Run Consensus Review

Invoke the Judge Panel workflow. See `references/consensus-review-contract.md` for the full contract.

```
Workflow(
  name='phase3-consensus',
  args={
    planContent: '<full plan text>',
    contextSummary: <Phase 0.3 output contextSummary>,
    grillSummary: <Phase 1 grill evidence>,
    taskIntakeSnapshot: <Phase 0 task intake snapshot>,
    tasks: <parsed tasks array from plan>
  }
)
```

The script reviews from 3 angles in parallel (architecture, risk, feasibility), scores 1-10 each, and synthesizes one verdict.

### Step 6: Act on Verdict

- **APPROVE**: Proceed to Step 7 (user approval).
- **ITERATE**: Address findings and re-run `Workflow(name='phase3-consensus', ...)`. Max 3 iterations. Report to user on 3rd failure.
- **REJECT**: Stop. Present reasons to user. Do NOT proceed to implementation.

### Step 7: User Approval

Present the plan for user approval before implementation.

On approval: auto-transition per Exit Contract.

## Output Contract

- `.claude/plans/YYYY-MM-DD_HHMMSS-<slug>.md` -- approved implementation plan with `json:tasks` block
- Updated `.claude/state/project-workflow-state.json`

## Exit Contract

1. After plan approval, update `.claude/state/project-workflow-state.json`:
   - `lastCompletedSkill="planning-implementation"`
   - `currentSkill="implementing-changes"`
   - `nextSkill="reviewing-implementation"`
   - `planPath=".claude/plans/<actual-file>.md"`

2. If `handoffPolicy=auto-continue`, announce and invoke `Skill(skill='implementing-changes')`:
   ```
   "Plan approved and saved to `.claude/plans/<actual-file>.md`.
   --> Continuing full workflow: invoking /implementing-changes."
   ```

3. If standalone (invoked directly by user), print:

```text
Plan complete and saved to `.claude/plans/<actual-file>.md`.

Execution options:
1. /implementing-changes (Recommended) — run the deterministic implementation workflow with task enrichment.
2. /project-workflow-claude continue — resume the full workflow.
3. Stop here — implement manually later.
```

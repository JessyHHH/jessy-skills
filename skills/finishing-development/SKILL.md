---
name: finishing-development
description: Use after verified completion to run retrospective learning, optionally configure memory compression cron, and choose how to finish the development branch. Presents merge, PR, keep, or discard options after verification evidence is current.
version: "v2.9"
---

# Finishing Development

## Purpose

Complete the development workflow with structured learning, optional memory compression, and a branch finish strategy. Ensure verification evidence is confirmed current before any outward-facing or destructive action.

## Inputs

- `.claude/state/project-workflow-state.json` — workflow metadata and verification results path.
- `.claude/state/verification-results.json` — Phase 6 verification evidence.

## Procedure

### Step 0: State Validation

Read `.claude/state/project-workflow-state.json`.

Verify required fields per `skills/project-workflow-claude/references/state-validation.md`.

**Required for this phase:** `verificationResultsPath`

- If any required field is missing or null: BLOCK. Report exactly what's missing.
- If `escapeHatchesUsed` is missing from state file: default to `[]` (backward compat).
- If all required fields present: continue to Step 1.

### 1. Reconfirm Verification

Before any outward-facing or destructive operation, verify that Phase 6 results are still current — no new code has been committed or changed since verification.

```bash
git status --porcelain
```

If unverified changes exist, return to `verifying-completion` before proceeding.

### 2. Session-End Retrospective (Phase 7.1)

Run a session retrospective in the background to extract lessons without blocking the main flow:

```
Agent(
  description='Session retrospective',
  prompt='Scan this session: errors, user corrections, skill misses, patterns. Extract lessons. Save to memory. Output retrospective report.',
  run_in_background=true
)
```

See `references/retrospective.md` for full details.

### 3. Self-Learning Triggers (Phase 7.2)

Evaluate inline triggers. See `references/retrospective.md` for the complete trigger table.

| Trigger | Action |
|---------|--------|
| Phase 6 failed >3 times on same issue | Load `diagnose` skill (if available) |
| Phase 5 found >5 CRITICAL/HIGH findings | Re-examine Phase 1 design assumptions |
| User corrected same pattern >=2 times | Save to memory as durable preference |
| Plan missed a relevant skill | Update claude-routing.md if pattern repeats |

### 4. Memory Management (Phase 7.3)

Memory compression is manual — no automatic cron. The user invokes `/finishing-development` when they want to compress project memory. Skip this step by default.

If the user explicitly requests memory compression, run the COMPRESS_OR_EXTRACT algorithm documented in `references/retrospective.md`.

### 5. Branch Finish (Phase 8)

Present a four-option menu for how to finish the development branch. See `references/branch-finish.md` for the complete command reference.

```
AskUserQuestion(
  question="What would you like to do?",
  options=[
    Merge locally,
    Push and create PR,
    Keep branch as-is,
    Discard this work
  ]
)
```

**NEVER:**
- Merge before Phase 6 verification is confirmed current.
- Push with failing tests.
- Discard without confirming (data loss).

### 6. Mark Complete

After the user's choice is executed (or skipped), update state:

```json
"status": "complete"
```

Persist to `.claude/state/project-workflow-state.json`.

## Output Contract

- Retrospective report (background, may complete after this skill exits).
- Manual memory compression (only if user explicitly requests).
- Branch finish action executed per user choice.
- State marked `status="complete"`.

## Exit Contract

1. Update `.claude/state/project-workflow-state.json`:
   - `lastCompletedSkill="finishing-development"`
   - `currentSkill=null`
   - `nextSkill=null`
   - `status="complete"`
2. There is no next skill. The workflow is complete.
3. If standalone, print:

```
Development workflow complete. State marked as complete.

No further workflow steps are required.
- Recommended next step: No next skill — the workflow is finished.
- Verification: all checks passed
- Retrospective: running in background
- Branch: [merged | PR created | kept as-is | discarded]
```

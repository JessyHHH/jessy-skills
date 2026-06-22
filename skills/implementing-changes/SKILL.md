---
name: implementing-changes
description: Execute an approved Codex implementation plan using supervised Codex subagents, file-overlap-aware dispatch, completion checks, and quick-gate evidence.
---

# Implementing Changes

Use this for Codex Phase 4, 4.5, and 4.6.

## Inputs

- `.codex/state/project-workflow-state.json`
- `.codex/plans/<plan>.md`
- `.codex/state/grill-evidence.json` when present
- `.codex/state/task-intake.json`

## Procedure

1. Validate state.
   - Required field: `planPath`.
   - Block if missing.

2. Load tasks.
   - Parse the plan `json:tasks` block.
   - Read referenced files fresh before implementation.
   - Resolve grill decisions and plan sections for each task.

3. Group by file overlap.
   - Tasks with disjoint write sets may run in parallel.
   - Tasks sharing files run serially.
   - Unknown write sets default to serial.

4. Dispatch Codex subagents.
   - Use `executor` or `worker` for bounded implementation.
   - Use `test-engineer` for focused test tasks.
   - Include owned files, forbidden files, evidence expectations, and first update window.
   - The main session monitors progress with `/agent` when needed.
   - If a subagent stalls, steer it once with the exact next action. If it remains stuck, stop or close it and record `BLOCKED_AGENT`.

5. Integrate results.
   - Inspect changed files.
   - Resolve overlapping edits in the main session.
   - Preserve unrelated user changes.

6. Completion guarantee.
   - Retry incomplete non-blocked tasks with narrower prompts, max 3 rounds.
   - Do not retry explicitly blocked tasks without user input.

7. Quick Gate.
   - `git diff --stat`.
   - Check expected files changed.
   - Check `expectedEvidence`.
   - Check `forbiddenEvidence` is absent.
   - Persist `.codex/state/quick-gate-results.json`.

## Exit

Update `.codex/state/project-workflow-state.json`:

- `lastCompletedSkill="implementing-changes"`
- `currentSkill="reviewing-implementation"`
- `nextSkill="verifying-completion"`
- `quickGateResultsPath=".codex/state/quick-gate-results.json"`

If Quick Gate passes and `handoffPolicy=auto-continue`, continue to `reviewing-implementation`.

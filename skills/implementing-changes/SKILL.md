---
name: implementing-changes
description: Execute an approved Phase 3 Plan and Spec with direct Codex writers, isolated Git worktrees, target tests, one focused diff review, and serial integration.
---

# Implementing Changes

Use this for Codex Phase 4, 4.5, and 4.6. Phase 3 already completed planning and plan review. Read `references/task-enrichment.md` and `references/worktree-quick-gate.md` before dispatching writers.

## Inputs

- `.codex/state/project-workflow-state.json`
- `.codex/plans/<plan>.md`
- `.codex/specs/<spec>.md`
- `.codex/state/grill-evidence.json` when present
- `.codex/state/task-intake.json`

## Procedure

1. Validate state and task contracts.
   - Block when `planPath` or `specPath` is missing.
   - Run `python3 skills/implementing-changes/scripts/phase4_guard.py validate-plan <plan>`.
   - Treat every task as one atomic deliverable. Never combine tasks in one writer prompt.

2. Build the execution schedule.
   - Run `python3 skills/implementing-changes/scripts/phase4_guard.py schedule <plan>`.
   - Follow `dependsOn` waves in order.
   - Run writers from the same wave concurrently when their files and resources are disjoint and slots are available.
   - Start each task's reviewer after its writer finishes. Reviewers for independent tasks may run concurrently.
   - Keep all integration serial in the main session.

3. Dispatch direct writers.
   - Read target and referenced files fresh.
   - Give each writer the approved Spec, its exact Plan task, allowed files, forbidden evidence, resources, and acceptance commands.
   - Give the subagent task-local context only. Use `fork_turns="none"` when the spawn interface supports history control.
   - Tell the writer to edit immediately and run the target acceptance commands. Do not require a planning-only turn or a second execution approval.
   - Use one unique linked Git worktree and branch per writer task, pinned to the recorded base commit.
   - Require `patchBackStrategy="harness-managed"` for writer subagents. Allow `no-isolation` only for main-session implementation or a recorded escape hatch; never run it concurrently.
   - Prohibit recursive delegation.
   - If the task needs an unlisted file, resource, behavior, or architectural decision, require `BOUNDARY_BLOCKED` and stop. Do not let the subagent expand scope.

4. Run target tests and collect evidence.
   - After the writer finishes, run `phase4_guard.py check-scope`, `git diff --check`, and the task's acceptance commands once in its worktree.
   - Codex main reads the actual diff and raw command output directly. Do not require the writer to paste the full diff into its response.
   - Stop on an unexpected file or failed target test.

5. Run one focused diff review.
   - Start one fresh read-only `code-reviewer` for the completed task.
   - Review only the task diff against the relevant approved Spec and Plan sections, including correctness and target-test adequacy.
   - Do not split this into specification and quality reviews. Do not explore unrelated repository areas or run unrelated tests.
   - If changes are required, send the findings to the writer for a minimal fix. The same reviewer checks only the repair diff; do not restart a full review cycle.

6. Integrate and finish Phase 4.
   - Follow `references/worktree-quick-gate.md`.
   - Integrate reviewer-approved task changes one task at a time in the main session.
   - Do not repeat target tests after every integration; Phase 6 owns fresh full verification.
   - Run `phase4_guard.py check-plan-scope` against the combined diff before leaving Phase 4.
   - Persist `.codex/state/phase4-execution-results.json` and `.codex/state/quick-gate-results.json`.

## Exit

Update `.codex/state/project-workflow-state.json`:

- `lastCompletedSkill="implementing-changes"`
- `currentSkill="reviewing-implementation"`
- `nextSkill="verifying-completion"`
- `quickGateResultsPath=".codex/state/quick-gate-results.json"`

Continue only when every non-blocked task has target-test evidence, one approved focused review, and a passing Quick Gate.

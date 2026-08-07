# Worktree Lifecycle And Quick Gate

Use a linked Git worktree as a disposable filesystem and index boundary for each writer task. It does not isolate services, databases, ports, caches, credentials, or files outside the worktree; declare those under `resources` and serialize conflicts.

## Prepare

1. Record the task base commit and verify the exact repository root.
2. Choose a unique branch and a validated path under a dedicated temporary root.
3. Inspect `git worktree list --porcelain` before creation.
4. Create the linked worktree:

```bash
git worktree add -b <task-branch> <task-worktree> <base-commit>
```

5. Confirm the worktree `HEAD` equals the recorded base and provide only that path to the writer.

Never point cleanup commands at the repository root, the main worktree, `$HOME`, or an unresolved variable.

## Diff And Target Tests

After the writer finishes, run:

```bash
python3 skills/implementing-changes/scripts/phase4_guard.py check-scope \
  <plan> <task-id> --worktree <task-worktree> --base <base-commit>
git -C <task-worktree> diff --check
git -C <task-worktree> status --short
git -C <task-worktree> diff --stat <base-commit>
git -C <task-worktree> diff <base-commit>
```

Any `BOUNDARY_VIOLATION` stops the task. Do not accept justification after the fact; revise the approved Phase 3 Plan first.

## Acceptance

Run the task's declared `acceptanceCommands` once inside its worktree. Do not automatically execute commands parsed from an untrusted plan; the main session inspects each command before running it. Missing command output is a failure.

Then run the single focused review described in `task-enrichment.md`. If the writer repairs a finding, rerun only the affected target test and scope check, and have the same reviewer check only the repair diff.

Record per task in `.codex/state/phase4-execution-results.json`:

```json
{
  "taskId": "T1-example",
  "baseCommit": "<sha>",
  "branch": "<branch>",
  "worktree": "<path>",
  "phase3Plan": "approved",
  "scopeGate": "PASS",
  "changedFiles": [],
  "acceptanceCommands": [],
  "focusedReview": "APPROVE | CHANGES_REQUIRED",
  "status": "APPROVED | REJECTED | BLOCKED"
}
```

## Serial Integration

The main session integrates one approved task at a time. Before each integration:

1. Confirm the main worktree has no overlapping uncommitted user changes.
2. Confirm the reviewed worktree diff has not changed.
3. Commit on the task branch and cherry-pick, or apply the reviewed patch, only when the approved plan authorizes that integration method.
4. Rebase or recreate dependent task worktrees from the newly accepted main `HEAD` before their execution.

Parallel writers may produce changes concurrently, but they never integrate concurrently.

## Cleanup

Remove a completed clean worktree with `git worktree remove <exact-task-worktree>`. Force removal of a rejected dirty worktree only after recording its diff, validating the exact path, and confirming the task contract authorizes discarding it. Delete only the exact task branch after integration or rejection is settled.

## Final Quick Gate

- Run `phase4_guard.py check-plan-scope <plan> --worktree <main-worktree> --base <base-commit>` against the combined diff.
- Every changed file belongs to an approved task allowlist.
- Every expected evidence item is present.
- Every forbidden evidence item is absent.
- Every acceptance command has recorded output from the stabilized task diff.
- Every task has one approved focused diff review.
- `git diff --check` passes.
- The combined implementation still satisfies the approved plan.

Persist the result to `.codex/state/quick-gate-results.json`. Do not enter Phase 5 on unresolved scope drift.

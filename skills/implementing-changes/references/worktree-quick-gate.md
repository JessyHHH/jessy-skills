# Worktree Review and Quick Gate

## Worktree Review Rules (Phase 4.5)

After the `phase4-implement` Workflow completes and BEFORE Phase 5 review, the master agent MUST review all worktree-managed diffs.

### Patch-Back Strategy Handling

| Strategy | Review Action |
|----------|--------------|
| `harness-managed` | Review the worktree diff. Validate against `expectedEvidence`. Verify no `forbiddenEvidence`. Merge back approved changes to the parent tree. |
| `no-isolation` | Changes are already in the working tree. Verify `expectedEvidence` with `grep` or `Bash` checks on changed files. |
| `external-report` | Flag as `DONE_WITH_CONCERNS`. Document what manual integration is needed. Do not attempt automatic merge. |

### Worktree Merge Procedure

For each harness-managed task:

1. Identify the worktree path from the workflow script output.
2. Run `git diff <worktree>` to review changes.
3. Cross-reference changed files against `task.files` — flag any unexpected files.
4. If all expected files changed and no forbidden evidence found, merge the worktree.
5. If issues found, document and either request a fix or proceed with concerns.

## Quick Gate Checks (Phase 4.6)

Run before entering Phase 5 review. Fail fast if evidence is missing.

### 1. Git Diff Stat Check

```bash
git diff --stat
```

Confirm expected files changed. Compare the file list against `task.files` from the plan. Flag:
- **Missing files:** A task declared a file but it does not appear in the diff.
- **Unexpected files:** A file appears in the diff but no task declared it.

### 2. Expected Evidence Check

For each task with `expectedEvidence` entries:
- Grep changed files for expected strings and patterns.
- Collect per-task results: which evidence items are present and which are missing.

```bash
# Example — task expects "TestFoo passes"
grep -l "TestFoo" <changed test files>
```

### 3. Forbidden Evidence Check

For each task with `forbiddenEvidence` entries:
- Grep changed files for forbidden strings and patterns.
- ANY match = FAIL for that task.

```bash
# Example — task forbids "TODO" in production code
grep -r "TODO" <changed files>
```

### 4. Unexpected File Check

Files in `git diff --stat` that do not appear in any task's `files` array are unexpected. Flag them and determine if they are intentional (e.g., generated files, vendored updates) or accidental.

## Fail Fast Rules

| Condition | Action |
|-----------|--------|
| Expected evidence missing | Report: which task + which evidence. Return to Phase 4 to fix OR proceed with documented concerns. |
| Forbidden evidence found | Report: which task + which evidence. FAIL immediately. Do not proceed to Phase 5 without resolution. |
| Unexpected files in diff | Report. If clearly benign (e.g., go.sum), note and continue. Otherwise flag for review. |

## Quick Gate Results Output

Persist to `.claude/state/quick-gate-results.json`:

```json
{
  "passed": true,
  "perTask": {
    "<taskId>": {
      "expectedPassed": true,
      "forbiddenClean": true,
      "filesMatch": true,
      "unexpectedFiles": [],
      "missingEvidence": [],
      "forbiddenFound": []
    }
  }
}
```

## Handoff to Reviewing-Implementation

The `quickGateResults` object MUST be passed to the `reviewing-implementation` skill. Quick Gate results are used by Phase 5 to compute per-task risk levels: tasks with >=2 items of missing `expectedEvidence` are classified as high-risk and receive Sonnet spec review (instead of Haiku).

Pass `quickGateResults` as part of the `Workflow(name='phase5-review')` args.

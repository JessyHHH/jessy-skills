---
name: implementing-changes
description: Use when an approved implementation plan with json:tasks is ready to execute. Enriches tasks with file contents, grill decisions, plan sections, and diffText; dispatches Agent() per task (serial implement→verify→self-review); handles Completion Guarantee loop; performs worktree review and quick gate; hands off to reviewing-implementation in full-workflow mode.
version: "v2.9"
---

# Implementing Changes

## Purpose

Execute the `json:tasks` block from an approved implementation plan using a deterministic Workflow pipeline. Enrich tasks with full context before dispatch so subagents start informed. After pipeline completion, review worktree diffs and run a Quick Gate before handing off to review.

## Inputs

- `.claude/state/project-workflow-state.json` — plan path and workflow metadata.
- `.claude/plans/<plan>.md` — the approved plan containing `json:tasks`.
- `.claude/state/grill-evidence.json` — resolved Grill decisions for enrichment (optional, may be absent for simple tasks).
- `.claude/state/task-intake.json` — task intake snapshot for cross-reference.

## Procedure

### Step 0: State Validation

Read `.claude/state/project-workflow-state.json`.

Verify required fields per `skills/project-workflow-claude/references/state-validation.md`.

**Required for this phase:** `planPath`

- If any required field is missing or null: BLOCK. Report exactly what's missing.
- If `escapeHatchesUsed` is missing from state file: default to `[]` (backward compat).
- If all required fields present: continue to Step 1.

### 1. Read State and Load Tasks

Read `.claude/state/project-workflow-state.json` to locate the plan path. Open the plan file and extract the `json:tasks` fenced code block. Parse to obtain the tasks array. Each task includes the expanded schema with `id`, `prompt`, `files`, `complexity`, `mutatesFiles`, `contextRefs`, `intakeRefs`, `grillRefs`, `expectedEvidence`, `forbiddenEvidence`, and `patchBackStrategy`.

### 2. Enrich Tasks

For each task in the array, perform the enrichment steps documented in `references/task-enrichment.md`:

a. **Read target files:** Use `Read(file_path='<path>')` on every file in `task.files`. Build `fileContents` array with complete file content per entry — subagents have large context windows, do not summarize.

b. **Resolve grill decisions:** Read `.claude/state/grill-evidence.json` if it exists. For each key in `task.grillRefs`, match against `ambiguityRegister[].id` or `assumptionLedger[].id` and extract the resolved `decision` (register) or `assumption` (ledger). Build `grillDecisions` array.

c. **Extract plan sections:** Read the plan. Extract approach steps and verification sections relevant to this task's scope. Build the `planSections` string.

d. **Generate per-task diff:** Before implementation the `diffText` field is initialized empty — it will be populated by the workflow script during execution for consumption by Phase 5 review.

e. **Build enriched task object:** Every enriched task must be self-contained — the subagent starts with blank context and receives only this prompt.

### 3. Normalize Evidence Arrays

Before invoking the Workflow script, normalize `expectedEvidence` and `forbiddenEvidence` arrays into readable text strings for prompt-oriented display, while preserving the canonical arrays in the task object:

```
expectedEvidenceText = expectedEvidence.map(e => `- ${e}`).join('\n')
forbiddenEvidenceText = forbiddenEvidence.map(e => `- ${e}`).join('\n')
```

### 4. Execute Implementation (Master-Driven Intelligent Parallel Dispatch)

Announce "**Phase 4: Implement** — Master-driven Agent dispatch with file-overlap-aware parallelism."

Master groups tasks by file overlap: tasks with disjoint file sets run in parallel; tasks sharing files run sequentially in dependency order.

#### 4a. Pre-Dispatch: Check File Overlap

Before dispatching any task, Master scans all `task.files` arrays:

1. **Build a file→task map:** `{ 'src/auth.go': ['T1', 'T3'], 'src/api.go': ['T2'] }`
2. **No shared files between T1 and T2** → can run in parallel
3. **T1 and T3 both touch src/auth.go** → must run sequentially (T1 first, T3 after)
4. **Group tasks into batches:** tasks within a batch have zero file overlap → dispatch in parallel. Batches run sequentially.

#### 4b. Per-Task Dispatch

**Stage 1 — Implement:**
Model: `simple` tasks → haiku, `medium`/`complex` → sonnet.
Isolation: `patchBackStrategy='harness-managed'` → `isolation='worktree'`, otherwise omit.

Build the implementer prompt from the enriched task:
```
buildImplementerPrompt(task):
  parts = [task.prompt]
  + fileContents (injected as code blocks: '### path\n```\ncontent\n```')
  + diffText (if any: '## Git Diff\n```diff\n' + diffText + '\n```')
  + grillDecisions (if any: '## Design Decisions\n- decision1\n- decision2')
  + planSections (if any: '## Task Section from Implementation Plan\n' + planSections)
  + expectedEvidence / forbiddenEvidence
  + isolation strategy instructions
  + "IMPORTANT: Read target file fresh before calling Edit. Do NOT rely on injected file contents for old_string construction."
```

Dispatch:
```
Agent(enhancedPrompt, {
  model: sonnet or haiku,
  isolation: 'worktree' or undefined,
  schema: {
    properties: {
      changedFiles: {type: 'array', items: {type: 'string'}},
      expectedEvidenceObserved: {type: 'array', items: {type: 'string'}},
      forbiddenEvidenceObserved: {type: 'array', items: {type: 'string'}},
      summary: {type: 'string'}
    }
  }
})
```

Record `taskChangedFiles[task.id]` from the result.

**Stage 2 — Quick Verify:**
```
Agent(
  'Quick verify these files: ' + task.files.join(', ') + '. Run build and affected tests. Report results.',
  { schema: { properties: { buildPassed: {type: 'boolean'}, testsPassed: {type: 'boolean'}, errors: {type: 'array', items: {type: 'string'}} }, required: ['buildPassed', 'testsPassed'] } }
)
```

**Stage 3 — Self-Review:**
If quick-verify failed → mark as FAILED immediately, skip self-review.

For `patchBackStrategy='external-report'` → auto-mark `DONE_WITH_CONCERNS`.

Otherwise dispatch:
```
Agent(
  'Self-review task ' + task.id + ': ' + task.files.join(', ') + '.\nCheck: all requirements met? Edge cases handled? Tests pass? Code matches project patterns?\nReturn status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT (specify what) | BLOCKED (explain why)',
  { schema: { required: ['status'], properties: { status: {type: 'string', enum: ['DONE', 'DONE_WITH_CONCERNS', 'NEEDS_CONTEXT', 'BLOCKED']}, concerns: {type: 'array', items: {type: 'string'}}, contextNeeded: {type: 'string'}, blockReason: {type: 'string'} } } }
)
```

Build `patchBackStatus`: `harness-managed:applied`, `no-isolation:applied`, or `external-report:pending-review`.

Collect per-task result:
```
{ taskId, status, concerns, contextNeeded, blockReason, changedFiles, expectedEvidenceObserved, forbiddenEvidenceObserved, patchBackStatus }
```

Record to `selfReviewStatus` array.

#### 4b. Completion Guarantee (Master-Driven Loop)

After all tasks processed, Master inspects `selfReviewStatus`:

1. **Identify stuck tasks:** Filter `status !== 'DONE' && status !== 'DONE_WITH_CONCERNS'`.
2. **NEEDS_CONTEXT tasks:** Re-enrich with missing context, re-dispatch implementer + quick-verify (no self-review) with fresh agent and different approach prompt. Max 3 retries per task.
3. **BLOCKED tasks:** Report block reason to user. Do NOT retry automatically.
4. **Compensation cap:** Max 2 compensation loops. After exhaustion, mark remaining as `STUCK` with `stuckReason`.

### 5. Worktree Review (Phase 4.5)

After the pipeline completes and before Quick Gate, review harness-managed worktree diffs following `references/worktree-quick-gate.md`:

- **harness-managed tasks:** Review the worktree diff. Validate against `expectedEvidence` and verify no `forbiddenEvidence`. Merge back approved changes to the parent tree.
- **no-isolation tasks:** Changes are already in-tree. Verify `expectedEvidence`.
- **external-report tasks:** Flag as `DONE_WITH_CONCERNS` and document what manual integration is needed.

### 6. Quick Gate (Phase 4.6)

Run the Quick Gate checks documented in `references/worktree-quick-gate.md`:

1. `git diff --stat` — confirm expected files changed. Compare against task files from the plan. Flag missing or unexpected files.
2. Grep for `expectedEvidence` per task — collect per-task results.
3. Grep for `forbiddenEvidence` per task — ANY match = FAIL.
4. **Fail fast:** If expected evidence missing or forbidden evidence found, report which task and which evidence. Return to Phase 4 to fix, or proceed with documented concerns.
5. **All pass:** Build `quickGateResults` object and persist to `.claude/state/quick-gate-results.json`.

```json
{
  "passed": true,
  "perTask": {
    "<taskId>": {
      "expectedPassed": true,
      "forbiddenClean": true,
      "filesMatch": true
    }
  }
}
```

### 7. Report

```
"Phase 4: Implemented
- Tasks: N/N completed, M passed, B failed
- Worktree merges: N reviewed, M approved
- Files: <count> changed
- Quick Gate: passed
-> Phase 5."
```

## Output Contract

- Enriched tasks array (canonical arrays preserved, text fields normalized for prompts).
- `.claude/state/quick-gate-results.json` with per-task evidence validation results.
- Per-task self-review statuses (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED) produced by the implementation pipeline — required as input by `reviewing-implementation`.
- Worktree merges complete for all `harness-managed` tasks.

## Exit Contract

1. Persist outputs to `.claude/state/quick-gate-results.json`.
2. Update `.claude/state/project-workflow-state.json`:
   - `lastCompletedSkill="implementing-changes"`
   - `currentSkill="reviewing-implementation"`
   - `nextSkill="verifying-completion"`
   - `quickGateResultsPath=".claude/state/quick-gate-results.json"`
3. If `handoffPolicy=auto-continue` and Quick Gate passed, announce and invoke `Skill(skill='reviewing-implementation')`.
4. If Quick Gate failed and `handoffPolicy=auto-continue`, return to step 6 (fix cycle) or proceed with documented concerns.
5. If standalone, print:

```
Implementation complete. Quick Gate results saved to `.claude/state/quick-gate-results.json`.

Recommended next step:
1. /reviewing-implementation (Recommended) — run the two-stage review with spec compliance and code quality checks.
2. Return to /implementing-changes if Quick Gate found issues.
3. /verifying-completion — only if review is explicitly skipped (not recommended).
```

---

## Edit Tool Safety Rules (HARD — MUST FOLLOW)

When calling the Edit tool to modify files, follow these rules exactly. Violating them causes "String to replace not found" or "No changes to make" errors that waste time and tokens.

### Before Edit
1. **Fresh Read required.** Read the target file immediately before constructing the Edit call. Do NOT rely on memory, stale plan line numbers, or previous reads from earlier turns.
2. **Exact old_string.** Copy `old_string` byte-for-byte from the Read output. Check: indentation (tabs vs spaces), surrounding whitespace, punctuation, and leading keywords (`type`, `func`, `var`, `const`, `package`, `import`).
3. **Unique anchor.** Include at least 2-3 lines of surrounding context to make the match unique. A single short line may appear multiple times in the file.

### On Edit Failure
4. **"String to replace not found":** Re-read the file at the target location. Copy the exact text from the fresh Read into `old_string`. Do NOT guess indentation. Do NOT retry the same old_string.
5. **"No changes to make" (old_string equals new_string):** The change already exists. Skip this edit — do NOT retry. Report success with evidence that the target content is already present.
6. **After 2 consecutive failures on the same file:** Switch to using Bash (Python, sed, or awk) instead of the Edit tool. The Edit tool requires exact byte-for-byte matching which may fail on edge cases.

### After Edit
7. **Verify the change.** Read the modified location to confirm the edit was applied correctly before marking the task complete.

### Verification Gate

After completing a task that used Edit:
1. Run `bash tests/test-controlled-edit-probe.sh` to confirm that exact-string matching patterns are correct.
2. If the probe fails, re-run the edit task with fresh file reads.

The regression probe validates the exact-string matching contract -- it confirms that `old_string` must include the full keyword (e.g., `type Retriever interface {` not just `Retriever interface {`).

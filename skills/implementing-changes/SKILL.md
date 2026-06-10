---
name: implementing-changes
description: Use when an approved implementation plan with json:tasks is ready to execute. Enriches tasks with file contents, grill decisions, plan sections, and diffText; invokes Workflow(name='phase4-implement'); performs worktree review and quick gate; hands off to reviewing-implementation in full-workflow mode.
version: "v2.7"
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

### 4. Execute Workflow Script

Announce "**Phase 4: Implement** — Workflow(pipeline) via phase4-implement.js."

Invoke:

```
Workflow(
  name='phase4-implement',
  args={tasks: enrichedTasks}
)
```

The script uses `pipeline()` (streaming, no barrier):
- **Stage 1 (Implement):** `agent(task.prompt, {model, isolation})` per task. `buildImplementerPrompt()` embeds `fileContents`, `grillDecisions`, and `planSections` when present, falling back to `contextRefs`/`grillRefs` references when absent. Complexity drives model: `simple` -> Haiku, `medium`/`complex` -> Sonnet. `patchBackStrategy='harness-managed'` -> `isolation='worktree'`, `no-isolation` -> `isolation='none'`.
- **Stage 2 (Quick Verify):** `agent(verify, {phase: 'Quick Verify', schema})` per task.
- **Stage 3 (Self-Review):** Each implementer reports `DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`.

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

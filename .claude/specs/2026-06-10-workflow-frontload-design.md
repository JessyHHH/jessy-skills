# Design Spec: Workflow Frontload for Phase 1-3 + Handoff Hardening

**Status:** Approved
**Date:** 2026-06-10
**Version:** v1.0

## 1. Goal

Fill the Workflow script gap in Phase 1-3 (detect, plan), harden handoff contracts, add Phase 4 task completion guarantee, and strengthen Phase 6 loop control. 6 targeted changes, no architecture overhaul.

## 2. Context

- **Project:** jessy-skills (77 AI Agent skills repository)
- **Core workflow:** project-workflow-claude v2.7 — 7-skill modular pipeline
- **Current state:** Phase 4-6 have Workflow scripts; Phase 1-3 are pure text Skill interpretation
- **Problem:** Session 60b27dfc showed 6 friction categories: missing Workflow for early phases, context duplication, fragile handoffs, manual loop tracking, no state validation, no phase-to-phase pipeline orchestrator

## 3. Approach

### Change 1: New Workflow — `phase1-detect-knowledge.js`

**What:** A Workflow script for detecting-environment Steps 5-7 (Context Artifact Freshness analysis + Skill Selection + Context Summary persistence).

**Why:** These steps are data-in → data-out computations. They take structured inputs (project type, commit SHA, git branch) and produce structured outputs (knowledge.md, context-summary.json, loaded skills list). Perfect Workflow fit.

**Input:** `{projectType, commitSha, branchName, contextMdExists, knowledgeMdExists, claudeMdExists, allFresh}`

**Flow:**
1. Phase: Analyze — spawn 2 agents in parallel: one analyzes codebase architecture, one analyzes skill inventory
2. Phase: Select — 1 agent selects skills based on codebase + task signals
3. Phase: Synthesize — 1 agent writes context-summary.json

**Output:** `{contextSummary, loadedSkills, contextWarnings}`

**NOT in Workflow:** Steps 1-4 (Bash commands, Glob, file detection) remain in SKILL.md — these need filesystem access.

### Change 2: New Workflow — `phase2-plan-generate.js`

**What:** A Workflow script for planning-implementation Steps 2-4 (Write Plan → Validate Schema → Collect Context).

**Why:** Plan generation is creative but the schema validation and context collection are deterministic. The Workflow enforces the json:tasks schema and ensures all context fields are populated before consensus review.

**Input:** `{specPath, specContent, contextSummary, grillSummary, taskIntake}`

**Flow:**
1. Phase: Generate — 1 agent writes the plan with json:tasks block
2. Phase: Validate — script validates each task against the schema (programmatic, not agent)
3. Phase: Enrich — 1 agent collects context for consensus review

**Output:** `{planContent, tasks, enrichedContext}`

### Change 3: Eliminate Context Duplication (Phase 4 → Phase 5)

**What:** Phase 4's `phase4-implement.js` output already includes `selfReviewStatus` with `changedFiles`. Add `diffText` (per-task git diff) and `fileContentsSnapshot` to the output contract. Phase 5 reads these directly — no re-reading files from disk.

**Changes to phase4-implement.js:**
- Stage 1 (Implement): after implementation, capture per-file diff via agent
- Output: add `perTaskDiffs: {taskId: diffText}` and `fileContentsSnapshots: {taskId: {file: content}}`

**Changes to phase5-review.js:**
- `constructDiff(task)`: read from `task.diffText` first, fall back to generating from fileContents
- `enrichTaskForReview(task)`: read from `task.fileContents` first (pre-populated by Phase 4 enrichment), skip disk reads

### Change 4: State Validation at Phase Boundaries

**What:** A reusable validation function in each skill's entry step. Before proceeding, verify `.claude/state/project-workflow-state.json` has all required fields for this phase.

**Implementation:**
- Add `references/state-validation.md` to project-workflow-claude — documents required fields per phase
- Each execution skill's SKILL.md gets a Step 0: "Validate state file has required fields for this phase. If missing, report what's missing and block."
- The check is: does the file exist? Do the required fields for THIS phase have non-null values? If expected upstream artifact path is set, does the file exist?

**Entry guards (new):**
- `designing-solutions`: requires contextSummaryPath
- `planning-implementation`: requires contextSummaryPath; if specPath AND grillEvidencePath are both null, check for "skip design" escape hatch
- `implementing-changes`: requires planPath
- `reviewing-implementation`: requires quickGateResultsPath
- `verifying-completion`: requires reviewResultsPath

### Change 5: Phase 6 Loop Control in Workflow

**What:** Move the loop-until-dry logic from master agent into `phase6-verify.js`.

**Current:** Master agent runs checks, calls Workflow, reads `shouldContinue`, re-runs checks, repeats.

**New:** `phase6-verify.js` is called ONCE with all check results. The script internally loops: analyze → fix → re-check → repeat until 2 consecutive dry rounds or max 10 iterations.

**New input:** `{projectType, checkCommands: [{name, command}], evidenceChecks: [...], maxIterations: 10}`

**Changes to phase6-verify.js:**
- Script does NOT run the loop internally (Workflow scripts can't run Bash).
- Instead: strengthened loop contract. Script returns explicit `mandatoryNextAction: "RE_RUN_CHECKS" | "DONE"`.
- Script tracks `dryRounds` and `totalIterations`, enforces max 10 upper bound.
- If `totalIterations >= 10 && !allPassed`: `mandatoryNextAction = "DONE"` with exhausted report.
- Master agent role is strictly mechanical: run Bash → pass results to Workflow → read `mandatoryNextAction` → if RE_RUN_CHECKS, re-run Bash and call Workflow again with incremented counts.

### Change 6: Phase 4 Task Completion Guarantee (Loop-Until-All-Done)

**What:** Guarantee ALL tasks in Phase 4 complete before handing off to Phase 5. Prevent silent task loss from agent failures, null results, or pipeline exceptions.

**Problem observed:** `pipeline()` can produce null results (agent skipped, threw, failed), leaving tasks incomplete without retry. Currently no mechanism to re-attempt failed tasks.

**3-layer defense:**

**Layer 1 — Internal retry in phase4-implement.js (new Stage 4):**
```
After Stage 3 (Self-Review) completes:
  Stage 4: Completion Guarantee
  → Collect all tasks where status is NOT 'DONE'
  → If 0 incomplete → return complete
  → If >0 incomplete → retry with different strategy (different agent, richer context)
  → Max 3 internal retries per batch
  → After 3 retries, mark remaining as STUCK and return to master
```

**Layer 2 — Master compensation loop (implementing-changes SKILL.md):**
```
If Workflow returns STUCK tasks:
  → Log stuckCount and stuckReasons
  → If reason CONTAINS 'NEEDS_CONTEXT': enrich context, re-invoke Workflow with ONLY stuck tasks
  → If reason CONTAINS 'BLOCKED': report to user with clear explanation
  → Max 2 compensation loops (total 5 attempts: 3 internal + 2 compensation)
```

**Layer 3 — Token budget hard cap (in phase4-implement.js):**
```js
const MAX_RETRY_TOKENS = 50000   // max 50k tokens for all retries
const MAX_RETRY_ROUNDS = 3        // max 3 retry rounds per batch

// Before each retry round:
if (retryTokensSpent > MAX_RETRY_TOKENS || retryRound >= MAX_RETRY_ROUNDS) {
  // Stop retrying, return remaining incomplete tasks as STUCK
  return { stuck: incompleteTasks, stuckReasons, retryBudgetExhausted: true }
}
```

**Key guards against infinite loop:**
- Only retry INCOMPLETE tasks, not the full batch
- Each retry uses different strategy (fresh agent, different prompt angle)
- 3 internal + 2 compensation = maximum 5 total attempts per task
- Token budget hard cap: 50k tokens for retries
- Final unresolved tasks → explicitly marked STUCK with reasons, reported to user
- No silent failure — every incomplete task has a documented reason

## 4. Files to Change

| File | Action | Change |
|------|--------|--------|
| `~/.claude/workflows/phase1-detect-knowledge.js` | **CREATE** | New Workflow for detect Steps 5-7 |
| `~/.claude/workflows/phase2-plan-generate.js` | **CREATE** | New Workflow for plan Steps 2-4 |
| `~/.claude/workflows/phase4-implement.js` | **MODIFY** | Add diffText + fileContentsSnapshot to output |
| `~/.claude/workflows/phase5-review.js` | **MODIFY** | Read diff/contents from input, skip disk reads |
| `~/.claude/workflows/phase6-verify.js` | **MODIFY** | Strengthened loop contract: explicit mandatoryNextAction, dryRounds tracking, max 10 iterations |
| `skills/detecting-environment/SKILL.md` | **MODIFY** | Add Workflow call for Steps 5-7; add Step 0 state validation |
| `skills/planning-implementation/SKILL.md` | **MODIFY** | Add Workflow call for Steps 2-4; add Step 0 entry guard (skip-design check) |
| `skills/implementing-changes/SKILL.md` | **MODIFY** | Add Step 0 state validation; add Phase 4 completion guarantee compensation loop (max 2 retries); update output contract for diff/contents |
| `skills/reviewing-implementation/SKILL.md` | **MODIFY** | Add Step 0 state validation; read diff/contents from Phase 4 output |
| `skills/verifying-completion/SKILL.md` | **MODIFY** | Add Step 0 state validation; simplify loop (call Workflow once) |
| `skills/designing-solutions/SKILL.md` | **MODIFY** | Add Step 0 state validation; add progress anchors per step |
| `skills/project-workflow-claude/SKILL.md` | **MODIFY** | Update orchestrator to reflect new Workflow scripts |
| `skills/project-workflow-claude/references/state-validation.md` | **CREATE** | Per-phase required fields documentation |
| `skills/project-workflow-claude/references/transition-rules.md` | **MODIFY** | Add skip-design documentation |
| `install.sh` | **MODIFY** | Install new workflow scripts |
| `.claude/state/project-workflow-state.json` | **MODIFY** | Add `escapeHatchesUsed` field |

## 5. Verification Strategy

### Per-Change Verification

**Change 1 (phase1-detect-knowledge):**
- `bash tests/test-verify.sh` passes
- `head -15 skills/*/SKILL.md` passes (YAML frontmatter check)
- context-summary.json validates against schema
- CONTEXT.md / knowledge.md header commit matches HEAD

**Change 2 (phase2-plan-generate):**
- Generated plan has valid json:tasks block
- All tasks pass schema validation (fields present, correct types)
- Consensus review runs without context warnings

**Change 3 (context dedup):**
- Phase 5 review completes without reading any files from disk
- Review findings match or exceed pre-change quality
- Token count for Phase 5 drops by ~30%

**Change 4 (state validation):**
- Missing required field → skill blocks with clear error message
- All required fields present → skill proceeds normally
- Skip-design escape hatch works: user says "skip design" → planning-implementation proceeds with warning

**Change 5 (phase6 loop):**
- 2 consecutive clean rounds → exits with `mandatoryNextAction: "DONE"`, `allPassed: true`
- Failure → fix → `mandatoryNextAction: "RE_RUN_CHECKS"` → master re-runs Bash
- Max iterations (10) hit → exits with `mandatoryNextAction: "DONE"` and exhausted report

**Change 6 (phase4 completion guarantee):**
- All tasks DONE after first pass → no retry needed
- Some tasks FAILED → Stage 4 retries with different agent strategy → max 3 internal retries
- Some tasks STUCK after 3 retries → master compensation loop (max 2) → remaining STUCK tasks reported to user
- Token budget exhausted (<50k for retries) → stops retrying, reports remaining tasks

### Integration Verification
- `bash tests/test-verify.sh` — full pipeline check
- `git diff --check` — no whitespace errors
- Manual dry-run: invoke `/project-workflow-claude` on a small test task

## 6. Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| New Workflows break existing phase flow | Low | Additive changes; existing call sites unchanged |
| Phase 5 no longer reads files, misses context | Medium | Phase 4 diffText + fileContentsSnapshot must be comprehensive; add fallback to disk read if snapshot missing |
| Loop-until-dry in Workflow can't run Bash commands | High | Master agent still runs Bash. New contract: master runs checks ONCE, passes ALL results to script which loops over fixes only. Script returns final verdict. Master does NOT re-run checks mid-loop. |
| Skip-design guard too aggressive | Low | Only blocks when BOTH specPath and grillEvidencePath are null AND no "skip design" escape hatch recorded; users can always say "skip design" |

## 7. Non-Goals (Explicitly Out of Scope)

- Single top-level Workflow orchestrating all 7 phases
- Modifying designing-solutions to use Workflow (needs AskUserQuestion)
- Changing Phase 4-6 core review/implement logic
- Adding new dependencies or MCP servers
- Creating test cases for skill-creator eval loop (this is infrastructure work, not a new skill)

---
name: reviewing-implementation
description: Use after implementation changes exist and before final verification. Runs two-stage review in the required order: spec compliance first, code quality second, with Master-driven serial Agent dispatch, tiered models, context injection, quick-gate risk handling. Hands off to verifying-completion in full-workflow mode.
version: "v2.9"
---

# Reviewing Implementation

## Purpose

Run a structured two-stage review of implemented changes: spec compliance first, code quality second. Never reverse the order. Use per-task independent pipeline with tiered models to minimize wall-clock time and token consumption.

## Inputs

- `.claude/state/project-workflow-state.json` — plan path, grill evidence path, quick gate results path.
- `.claude/plans/<plan>.md` — approved plan with `json:tasks` block.
- `.claude/state/quick-gate-results.json` — per-task expectedEvidence/forbiddenEvidence validation from `implementing-changes`.
- `.claude/state/grill-evidence.json` — resolved Grill decisions (optional).
- Implementation output — enriched tasks with `diffText` populated, `selfReviewStatuses`, and changed files.

## Review Layers

See `references/review-layers.md` for the full five-layer review model.

Summary:

| Layer | Name | Model | Gates |
|-------|------|-------|-------|
| 1 | Fast Gate | N/A (bash) | Strongly recommended — runs before script |
| 2 | Spec Review | Haiku (Sonnet for high-risk) | Simple skips; med/complex runs |
| 3 | Code Review | Sonnet (correctness/safety), Haiku (simplicity) | Simple skips; medium=1 agent; complex=3 |
| 4 | Adversarial Verify | Haiku (1-3 skeptics) | Simple auto-confirms; complex=3 |
| 5 | Final Review | Haiku | Skip if <2 tasks or no shared files |

## Procedure

### Step 0: State Validation

Read `.claude/state/project-workflow-state.json`.

Verify required fields per `skills/project-workflow-claude/references/state-validation.md`.

**Required for this phase:** `quickGateResultsPath`

- If any required field is missing or null: BLOCK. Report exactly what's missing.
- If `escapeHatchesUsed` is missing from state file: default to `[]` (backward compat).
- If all required fields present: continue to Step 1.

### 1. Prepare Context

Before invoking the review Workflow script, perform context injection:

a. **Context Injection (MANDATORY):** For each task, pre-extract spec sections from the plan text — inject as `task.specSection`. Pre-read task target files — inject as `task.fileContents`. Resolve `grillRefs` against `.claude/state/grill-evidence.json` — inject as `task.grillDecisions`. Agents receive pre-digested context; no file exploration needed.

b. **Diff Generation:** For each task, pre-compute `git diff <base>..<head> -- <task.files>` — inject as `task.diffText`. Code reviewers only examine changed lines. The `diffText` field is the canonical field for Phase 5 review diffs.

### 2. Fast Gate (Strongly Recommended)

Run bash checks BEFORE invoking `phase5-review.js`. Build `fastGateResults`:

```bash
git diff --stat
git diff --check
# files-exist check for each task.files entry
# import check for Go projects
```

Script logs an advisory warning if Fast Gate is missing, but guardrails still apply.

### 3. Collect Inputs

Collect the following inputs for the Workflow call:
- `planPath` — path to the approved plan file.
- `planText` — full text of the approved plan.
- `changedFiles` — list of files modified during implementation.
- `tasks` — enriched task array from `implementing-changes` (with `diffText`, `specSection`, `fileContents`, `grillDecisions` populated).
- `selfReviewStatuses` — from Phase 4 output (`DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`).
- `fastGateResults` — from the Fast Gate checks above.
- `quickGateResults` — from `.claude/state/quick-gate-results.json`.
- `grillEvidence` — from `.claude/state/grill-evidence.json` (or null if absent).

### 4. Execute Review (Master-Driven Agent Dispatch)

Announce "**Phase 5: Two-Stage Review** — Master-driven serial Agent dispatch."

Master processes tasks **sequentially**. For each task, Master dispatches review agents: Spec Review → Code Review → Adversarial Verify. Then a cross-task Final Review agent.

#### 4a. Complexity Gating (Master Decision Before Dispatch)

Before dispatching review agents for a task, Master checks complexity:

```
complexity = task.complexity || 'medium'

shouldSkipSpec       = complexity === 'simple'
shouldSkipCode       = complexity === 'simple'
codeDepth            = complexity === 'complex' ? 'full' : 'correctness-only'
shouldSkipAdversaria = complexity !== 'complex'
adversarialSkeptics  = complexity === 'complex' ? 3 : (complexity === 'medium' ? 1 : 0)
```

#### 4b. Per-Task Review Dispatch (Serial)

For each task (skip if self-review status is FAILED or BLOCKED):

**Stage 1 — Spec Review** (skip if `shouldSkipSpec`):
Model: task.riskLevel === 'high' ? sonnet : haiku

Build guarded spec prompt with injected context:
```
'Spec compliance review for task Tn.
DO NOT read any plan files. All context provided.
## Task Specification: <task.enrichedContext or task.prompt>
## Self-Review Status: status=X, concerns=Y
## Instructions: Check implementation matches spec exactly. Nothing extra? Nothing missing?
Verify expectedEvidence: <task.expectedEvidence>
Check forbiddenEvidence: <task.forbiddenEvidence>
Return APPROVE, ITERATE, or REJECT with specific issues.
## REVIEW GUARDRAILS (HARD):
1. Maximum 5 file reads total.
2. DO NOT read any file more than once.
3. FORBIDDEN: go build, go test, go vet, grep, find. You are a reviewer, not a builder.
4. Maximum 3 thinking blocks.'
```

Dispatch: `Agent(specPrompt, { schema: SPEC_SCHEMA, model })`

If verdict !== APPROVE → record spec failure, skip code review for this task.

**Stage 2 — Code Review** (skip if `shouldSkipCode`):

If codeDepth === 'correctness-only':
- Dispatch 1 agent (model: sonnet) for correctness review with diff
If codeDepth === 'full':
- Dispatch 3 agents in parallel (correctness=sonnet, safety=sonnet, simplicity=haiku)

Each agent receives:
```
'Review CORRECTNESS/SAFETY/SIMPLICITY for task Tn.
## Git Diff (ONLY review changed lines): <task.diffText>
## Full File Contents (context only, do not review unchanged lines): <task.fileContents>
Flag findings with severity CRITICAL/HIGH/MEDIUM/LOW.
## REVIEW GUARDRAILS (HARD): [same 5 rules as spec review]'
```

Dispatch: `Agent(codePrompt, { schema: REVIEW_SCHEMA, model })`
Tag each finding with taskId and reviewType.

**Stage 3 — Adversarial Verify** (gated by complexity):

For each CRITICAL finding in the task:
- If complex (3 skeptics): Dispatch 3 haiku agents in parallel, each trying to REFUTE the finding. Survives if ≥2/3 fail to refute.
- If medium (1 skeptic): Dispatch 1 haiku agent to refute. If refuted → downgrade to HIGH.
- If simple: auto-confirm (no skeptics).

Skeptic dispatch:
```
Agent('Try to REFUTE this finding. Default to refuted=false if uncertain.\nFinding: <description>\nFile: <file> [line <line>]',
  { schema: SKEPTIC_SCHEMA, model: 'haiku' })
```

Collect verified critical findings.

#### 4c. Final Review (Cross-Task)

Skip if ≤1 task or no shared files between tasks.

Dispatch 1 agent (model: haiku, summary-based — DO NOT re-read files):
```
'CROSS-TASK CONSISTENCY CHECK:
## Changed Files: <changedFiles.join(', ')>
## Per-Task Findings Summary: <allFindings as bullet list>
## Spec Failures: <specFailed summary>
Check for: integration gaps, cross-task conflicts, duplicate patterns.
Return: verdict (APPROVE/ITERATE/REJECT), issues, reasons, summary.'
```

Dispatch: `Agent(prompt, { schema: FINAL_REVIEW_SCHEMA, model: 'haiku' })`

Master determines final verdict: Final Review must be APPROVE for pass; any unresolved CRITICAL or SPEC_FAILURE blocks pass.

### 5. Fix-and-Retry Loop (Master Decision)

Master inspects collected results:
- If `criticalCount > 0`: Dispatch fix Agent → re-run review. Max 3 iterations.
- If `specFailed.length > 0`: Address spec gaps → fix implementation → re-run review.
- Report to user on 3rd failure.

**Red Flags (NEVER):**
- Start code quality before spec compliance is complete.
- Skip either stage.
- Accept "close enough".
- Skip context injection before review.
- Use Sonnet for simplicity review or final review (Haiku is sufficient and faster).

### 7. Report

```
"Phase 5: Reviewed
- Spec Compliance: [passed/total]
- Code Quality: N findings (M CRITICAL, H HIGH)
- Models: N Haiku + M Sonnet
-> Phase 6."
```

## Output Contract

- Review results with per-task findings, critical count, spec compliance status.
- Updated `tasks` array with any fixes applied during the fix-and-retry loop.

## Exit Contract

1. Persist review results to `.claude/state/review-results.json`.
2. Update `.claude/state/project-workflow-state.json`:
   - `lastCompletedSkill="reviewing-implementation"`
   - `currentSkill="verifying-completion"`
   - `nextSkill="finishing-development"`
   - `reviewResultsPath=".claude/state/review-results.json"`
3. If `handoffPolicy=auto-continue` and review passed (all spec tasks passed, no unresolved critical findings), announce and invoke `Skill(skill='verifying-completion')`.
4. If review found critical issues and `handoffPolicy=auto-continue`, return to fix-and-retry (step 6) first, then invoke `Skill(skill='verifying-completion')`.
5. If standalone, print:

```
Review complete. Results saved to `.claude/state/review-results.json`.

Recommended next step:
1. /verifying-completion (Recommended) — enforce the Iron Law with fresh verification evidence.
2. /implementing-changes — if findings need implementation fixes.
3. Stop here — keep review findings as-is.
```

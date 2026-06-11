---
name: reviewing-implementation
description: Use after implementation changes exist and before final verification. Runs two-stage review in the required order: spec compliance first, code quality second, with per-task pipeline, tiered models, context injection, quick-gate risk handling, and Workflow(name='phase5-review'). Hands off to verifying-completion in full-workflow mode.
version: "v2.7"
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

### 4. Execute Review Workflow

Announce "**Phase 5: Two-Stage Review** — per-task independent pipeline via phase5-review.js."

```
Workflow(
  name='phase5-review',
  args={
    planPath,
    planText,
    changedFiles,
    tasks: [...enrichedTasks],
    selfReviewStatuses: [...],
    fastGateResults: {...},
    quickGateResults: {...},
    grillEvidence: {...}
  }
)
```

The script uses **per-task independent pipeline**:
- **Spec Review:** Context injected directly. Haiku by default, Sonnet for high-risk tasks (>=2 missing expectedEvidence from quickGateResults). Simple tasks skip.
- **Code Review:** Reviewers receive pre-computed `git diff` via `diffText` — only review changed lines. Tiered models: correctness=Sonnet, safety=Sonnet, simplicity=Haiku. Simple tasks skip entirely; medium gets correctness-only; complex gets 3-agent parallel.
- **Adversarial Verification:** Runs per-task inline. Complexity-gated: complex=3 skeptics, medium=1, simple=auto-confirm. All skeptics use Haiku.
- **Final Review:** Haiku synthesis of per-task findings. Cross-task consistency check. Skipped when <=1 task or no shared files.

### 5. Anti-Exploration Guardrails

All review agent prompts inject these rules from `references/review-prompt-guardrails.md`:

```
Maximum 5 file reads. DO NOT read same file twice.
FORBIDDEN: go build, go test, go vet, grep exploration.
Maximum 3 thinking blocks.
```

### 6. Fix-and-Retry Loop

Read the script output: `{criticalCount, highCount, findings, specFailed, finalVerdict}`.

- If `criticalCount > 0`: Agent fixes CRITICAL issues -> re-run Workflow. Max 3 iterations.
- If `specFailed.length > 0`: Address spec gaps -> fix implementation or update plan -> re-run Workflow.
- Report to user on 3rd failure.

**Red Flags (NEVER):**
- Start code quality before spec compliance is complete.
- Skip either stage.
- Accept "close enough".
- Skip context injection before invoking Phase 5.
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

---

## Workflow Script Rules (HARD — Plain JavaScript Only)

When writing or reviewing Workflow scripts (code passed to the `Workflow()` tool), these rules apply:

### Forbidden in Workflow Scripts
- TypeScript type annotations: `const x: string[] = ...`, `function f(a: number): void {}`
- TypeScript interfaces: `interface MyResult { ... }`
- TypeScript generics: `Array<string>`, `Promise<Result>`, `<T>`
- TypeScript type assertions: `x as string`, `<string>x`
- TypeScript enums: `enum Color { Red, Green }`
- Union types in executable positions: `type Mode = "A" | "B"` (in JSON Schema use plain JS: `{ type: 'string', enum: ['A', 'B'] }`)

### Required in Workflow Scripts
- ALL scripts must be plain JavaScript (ES2020)
- Use `const`, `var`, `function` — no type annotations
- Use JSON Schema objects for structured output: `{ type: 'object', properties: { name: { type: 'string' } } }` — these are plain JS objects, NOT TypeScript
- After authoring a script, run `node --check <scriptPath>` before passing to `Workflow()`

### On Parse Error
If `Workflow()` returns "Invalid workflow script: Script parse error", inspect the reported line and surrounding lines for:
- Type annotations (`: string`, `: number[]`)
- Arrow functions with typed parameters
- Interface/type declarations
- Remove ALL TypeScript syntax from the offending lines and retry.

---
name: verifying-completion
description: Use before claiming work is complete, fixed, passing, ready, committed, or mergeable. Enforces the Iron Law with fresh verification evidence, project-specific commands, Master-driven loop-until-dry with Agent fix dispatch, and hard cap at 10 iterations. Hands off to finishing-development in full-workflow mode.
version: "v2.9"
---

# Verifying Completion

## Purpose

Enforce the Iron Law: NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE. Run all project-type verification commands, invoke the phase6-verify Workflow for loop-until-dry fix cycles, and persist verification results before any completion claim.

## Inputs

- `.claude/state/project-workflow-state.json` — workflow metadata, project type, grill evidence path, quick gate results path.
- `skills/project-workflow-claude/references/iron-law.md` — full Iron Law discipline.
- `.claude/state/grill-evidence.json` — Grill evidence for semantic validation (optional).
- `.claude/state/quick-gate-results.json` — Quick Gate results from `implementing-changes`.

**Note on review-results.json:** The Phase 5 review results (`.claude/state/review-results.json`) produced by `reviewing-implementation` are NOT rechecked by this skill. Phase 5 review is a separate gate with its own fix-and-retry loop. This skill verifies implementation completion evidence (build, test, lint, security), not review findings. If review findings indicate unresolved issues, those must be addressed before entering Phase 6.

## Procedure

### Step 0: State Validation

Read `.claude/state/project-workflow-state.json`.

Verify required fields per `skills/project-workflow-claude/references/state-validation.md`.

**Required for this phase:** `reviewResultsPath`

- If any required field is missing or null: BLOCK. Report exactly what's missing.
- If `escapeHatchesUsed` is missing from state file: default to `[]` (backward compat).
- If all required fields present: continue to Step 1.

### 1. Load the Iron Law

Read `skills/project-workflow-claude/references/iron-law.md` to enforce the complete verification discipline: Gate Function, Red Flags, Rationalization Prevention, TDD Red-Green Verification, Agent Delegation Verification, and Evidence Standard.

### 2. Run All Verification Commands

Execute ALL commands for the detected project type using Bash. Collect results as `[{name, command, exitCode, stdout, stderr}]`.

See `references/verification-commands.md` for the complete command sets per project type:

- **Go:** `go mod tidy`, `go build ./...`, `go vet ./...`, `go test -race -count=1 ./...`, vulnerability scan, lint check.
- **Vue/Node:** `npm ci` (or `pnpm install`), `npx tsc --noEmit` (if TypeScript), `npm test`, `npm run lint`.
- **Skills Repository:** Modular structure checks (frontmatter validation, skill count, reference integrity), `grep` for unresolved issues, `git diff --check`.

### 3. Build Evidence Checks

From `quickGateResults` and grill evidence, build the `evidenceChecks` array:

```json
"evidenceChecks": [
  {"taskId": "T1", "expectedPassed": true, "forbiddenClean": true, "filesMatch": true},
  ...
]
```

Extract `quickGateEvidence` from `.claude/state/quick-gate-results.json` and `grillEvidencePath` from the state file.

### 4. Verification Loop (Master-Driven Loop Until Dry)

Announce "**Phase 6: Verify** — Iron Law enforcement. Master-driven loop-until-dry."

Master runs the verification loop directly. No Workflow script — Master executes Bash, inspects results, dispatches fix agents, repeats.

#### 4a. Initialize Loop State

```
dryRounds = 0
totalIterations = 0
MAX_ITERATIONS = 10
```

#### 4b. Loop Body

**Each iteration:**

1. **Run ALL verification commands** (from Step 2) — fresh Bash output each time.
2. **Evaluate evidence checks** (from Step 3) — re-check `file-exists`, `text-present`, `text-absent` evidence.
3. **Count failures:** command failures (exitCode !== 0) + evidence failures (passed === false).

**If 0 failures:**
```
dryRounds += 1
if dryRounds >= 2:
  verdict = 'PASSED'
  mandatoryNextAction = 'DONE'
  exit loop
else:
  verdict = 'IN_PROGRESS'
  mandatoryNextAction = 'RE_RUN_CHECKS'
  totalIterations += 1
  continue loop (re-run checks for a clean round)
```

**If failures > 0:**
```
dryRounds = 0  // dry streak broken
totalIterations += 1

if totalIterations >= MAX_ITERATIONS:
  verdict = 'EXHAUSTED'
  mandatoryNextAction = 'DONE'
  exit loop (report remaining failures, do NOT proceed to finishing-development)
else:
  verdict = 'IN_PROGRESS'
  mandatoryNextAction = 'RE_RUN_CHECKS'
  // Master dispatches fix agents, then continues loop
```

#### 4c. Fix Dispatch (When Failures Exist)

Master dispatches fix agents for each failure:

**Command failures:** Dispatch 1 Agent per failed check:
```
Agent('Check "' + failure.name + '" failed.
Command: ' + failure.command + '
Stderr: ' + (failure.stderr || '(none)') + '
Stdout: ' + (failure.stdout || '(none)') + '
Fix the issue with MINIMAL changes. Do NOT redesign or refactor.',
  { isolation: 'worktree', model: 'sonnet' })
```

**Evidence failures:** Dispatch 1 Agent per failed evidence:
```
Agent('Evidence check "' + ef.id + '" (' + ef.type + ': ' + ef.description + ') failed.
Details: ' + (ef.details || '(none)') + '
Fix the issue with MINIMAL changes.',
  { isolation: 'worktree', model: 'sonnet' })
```

After all fix agents complete, Master re-runs the loop body (Step 4b) with fresh Bash checks and re-evaluated evidence.

### 6. Persist Verification Results

Write `.claude/state/verification-results.json`:

```json
{
  "timestamp": "<ISO 8601>",
  "allPassed": true,
  "dryRounds": 2,
  "projectType": "skills-repo",
  "checkResults": [...],
  "evidenceChecks": [...]
}
```

### 7. Report

```
"Phase 6: Verified
- Build: checkmark (exit 0)
- Test: checkmark (N/N PASS)
- Lint: checkmark (0 warnings)
- Security: checkmark (0 vulnerabilities)"
```

## Output Contract

- `.claude/state/verification-results.json` with full check results, evidence validation, and dry round status.
- Fresh verification evidence for all checks (no cached or stale results).

## Exit Contract

1. Persist `.claude/state/verification-results.json`.
2. Update `.claude/state/project-workflow-state.json`:
   - `lastCompletedSkill="verifying-completion"`
   - `currentSkill="finishing-development"`
   - `nextSkill=null`
   - `verificationResultsPath=".claude/state/verification-results.json"`
3. If `handoffPolicy=auto-continue` and `allPassed=true` with dry rounds complete, announce and invoke `Skill(skill='finishing-development')`.
4. If verification failed and `handoffPolicy=auto-continue`, do NOT transition. Report failure and await user guidance.
5. If standalone, print:

```
Verification complete. Results saved to `.claude/state/verification-results.json`.

Recommended next step:
1. /finishing-development (Recommended) — run retrospective, optionally enable memory compression, and choose how to finish the branch.
2. Stop here — keep branch as-is with verified completion evidence.
```

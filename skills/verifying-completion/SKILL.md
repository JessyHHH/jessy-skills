---
name: verifying-completion
description: Use before claiming work is complete, fixed, passing, ready, committed, or mergeable. Enforces the Iron Law with fresh verification evidence, project-specific commands, Workflow(name='phase6-verify'), and loop-until-dry fixes. Hands off to finishing-development in full-workflow mode.
version: "v2.7"
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

### 4. Invoke Verification Workflow

Announce "**Phase 6: Verify** — Iron Law enforcement via phase6-verify.js."

```
Workflow(
  name='phase6-verify',
  args={
    projectType: '<go|vue|node|skills-repo>',
    checkResults: [...],
    dryRounds: <current>,
    evidenceChecks: [...],
    quickGateEvidence: <from quick-gate-results.json>,
    grillEvidencePath: '<.claude/state/grill-evidence.json>'
  }
)
```

### 5. Loop Until Dry

The script returns `{allPassed, dryRounds, shouldContinue}`.

- `shouldContinue=false, allPassed=true` -> DONE (Iron Law satisfied, 2 consecutive dry rounds).
- `shouldContinue=true` -> Master re-runs ALL Bash checks -> re-invoke script with updated `checkResults` and current `dryRounds` value.
- **Safety cap:** 10 total invocations. Report to user if cap reached.

If `allPassed=false` after the cap, report the failing checks and do NOT proceed to `finishing-development`.

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

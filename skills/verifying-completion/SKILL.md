---
name: verifying-completion
description: Enforce Codex completion verification with fresh command output, semantic evidence checks, loop-until-dry repair, and .codex verification artifacts.
---

# Verifying Completion

Use this for Codex Phase 6 before any completion claim.

## Inputs

- `.codex/state/project-workflow-state.json`
- `.codex/state/review-results.json`
- `.codex/state/quick-gate-results.json`
- `.codex/state/grill-evidence.json` when present
- `references/verification-commands.md`

## Procedure

1. Validate state.
   - Required field: `reviewResultsPath`.
   - Block if missing unless review was explicitly skipped.

2. Build verification command list.
   - Skills repository: `git diff --check`, `bash tests/test-*.sh`, skill validation for changed skills, helper script dry-runs.
   - Go/Node/Vue projects: use the project-specific commands in `references/verification-commands.md`.

3. Build semantic evidence checks.
   - Expected files exist.
   - Expected text or behavior is present.
   - Forbidden evidence is absent.
   - Quick Gate remains valid.

4. Loop until dry.
   - Run all verification commands fresh.
   - Evaluate semantic checks fresh.
   - If clean, rerun once for a second clean round when risk warrants it.
   - If failures remain, dispatch `build-fixer`, `debugger`, `test-engineer`, or `worker` subagents by non-overlapping file groups.
   - Re-run checks after fixes.
   - Stop after 10 iterations and report `EXHAUSTED`.

5. Persist `.codex/state/verification-results.json`.

## Exit

Update `.codex/state/project-workflow-state.json`:

- `lastCompletedSkill="verifying-completion"`
- `currentSkill="finishing-development"`
- `nextSkill=null`
- `verificationResultsPath=".codex/state/verification-results.json"`

If all checks pass and `handoffPolicy=auto-continue`, continue to `finishing-development`.

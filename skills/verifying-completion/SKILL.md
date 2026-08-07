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

5. Refresh Graphify after code verification passes.
   - Run this only after every code, scope, and semantic check is clean and
     before transitioning to `finishing-development`.
   - Codex main runs the refresh serially from each canonical repository that
     both has an existing `graphify-out/graph.json` and contains accepted code
     changes from the current workflow. Never refresh from a writer worktree.
   - Use `graphify update .` through `command -v graphify` or a
     project-approved absolute executable. Do not add `--force` unless the
     approved task explicitly requires rebuilding after intentional deletion.
   - Confirm Graphify changed only generated graph output, then validate the
     resulting graph with `graph_stats` and at least one task-relevant node or
     relationship. Verify graph claims against current files with `rg` or a
     direct read.
   - Record per-repository command, status, graph path, MCP `project_path`, and
     validation evidence. Use `updated`, `not_needed`, `unavailable`, or
     `failed`; never infer success from command intent.
   - An unavailable or failed refresh yields `PASS_WITH_RISK` with the graph
     explicitly marked stale. If the project contract requires a current graph,
     treat it as `FAIL` and do not exit Phase 6.

6. Persist `.codex/state/verification-results.json`, including the structured
   Graphify refresh result when the project has a graph.

## Exit

Update `.codex/state/project-workflow-state.json`:

- `lastCompletedSkill="verifying-completion"`
- `currentSkill="finishing-development"`
- `nextSkill=null`
- `verificationResultsPath=".codex/state/verification-results.json"`

If all checks pass and `handoffPolicy=auto-continue`, continue to `finishing-development`.

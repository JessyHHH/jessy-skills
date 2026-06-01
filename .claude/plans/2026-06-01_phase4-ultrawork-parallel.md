# Implementation Plan: Phase 4 Ultrawork Parallel

**Date:** 2026-06-01
**Status:** Final — implemented (Phase 4-6 complete)

## Goal

Replace Phase 4's Workflow-based orchestration with ultrawork's proven parallel pattern: classify → fire all simultaneously → collect → report. Removes Workflow opt-in dependency. Phase 5+6 handle review and verification.

## Context

- Current: Phase 4 tries to use Workflow tool (opt-in required). Model falls back to sequential Agent calls.
- Session evidence: User had to say "你是并发执行" because model defaulted to sequential.
- Source pattern: OMC ultrawork's parallel execution engine.
- Deconfliction: Phase 4 does NOT do review (Phase 5) or verification (Phase 6).

## Approach

Replace Phase 4 section (Workflow-based, ~45 lines) with ultrawork pattern (~25 lines).

### New Phase 4 structure

1. **ANNOUNCE** — "**Phase 4: Implement** — parallel execution via ultrawork pattern."

2. **CLASSIFY** tasks by complexity:
   - Simple (typo, config, one-liner) → model='haiku'
   - Standard (feature, refactor) → model='sonnet' (default)
   - Complex (architecture, debug race condition) → model='opus'
   - Default: 'sonnet'
   - Group into waves: independent tasks fire together; tasks with file dependencies on prior wave results are deferred to the next wave. No two tasks touching the same file fire in the same wave.

3. **FIRE ALL** simultaneously — never serialize independent work:
   ```
   // Wave 1: independent tasks (no overlapping files)
   Agent(description='Implement: <task1>', prompt='<detailed prompt>', 
         subagent_type='general-purpose', model='sonnet', run_in_background=true)
   Agent(description='Implement: <task2>', prompt='<detailed prompt>', 
         subagent_type='general-purpose', model='haiku', run_in_background=true)

   // Wave 2: tasks depending on wave-1 file changes (await wave 1 first)
   Agent(description='Implement: <task3>', prompt='<detailed prompt>', 
         subagent_type='general-purpose', model='sonnet', run_in_background=true)
   ```
   Within each wave, fire all agents in ONE message. Between waves, await wave completion before firing next.

4. **COLLECT** results as they complete:
   - Success → mark done
   - Failure → immediately spawn a retry Agent(..., run_in_background=true) — do NOT wait for other tasks to finish before retrying. The retry runs concurrently with still-running wave agents. After 3 failed attempts, mark as blocked.
   - Use `Bash(command='git diff --stat')` to show changes

5. **REPORT** → auto-transition to Phase 5:
   ```
   "Phase 4: Implemented
   - Tasks: N/N completed (M retried)
   - Files: <count> changed
   → Phase 5."
   ```

## Files

| Action | File | Description |
|--------|------|-------------|
| MODIFY | `skills/project-workflow-claude/SKILL.md` | Replace Phase 4 section (~45→25 lines) |
| MODIFY | `skills/project-workflow-claude/SKILL.md` | Update OMC Compliance table: add 'sonnet' default for Agent model |

## Change Log

### v1 → v2 (2026-06-01 — Critic fixes)
- CLASSIFY step: Added wave-based dependency sorting (no two tasks touching same file fire in same wave)
- COLLECT step: Changed retry from "re-queue" to "re-fire as new background agent in same wave" with blocked marking
- OMC Compliance table: Clarified Agent tool with `general-purpose, model='sonnet' default`

### v2 → v3 (2026-06-01 — Critic iteration-3 fixes)
- FIRE ALL example: Replaced flat batch with wave-demarcated example (Wave 1 / Wave 2 with `//` comments)
- FIRE ALL description: Changed "All fired in ONE message" to "Within each wave, fire all agents in ONE message. Between waves, await wave completion before firing next."
- COLLECT retry: Changed "re-fire as new background agent in the same wave (no serial wait)" to "immediately spawn a retry Agent(..., run_in_background=true) — do NOT wait for other tasks to finish before retrying. The retry runs concurrently with still-running wave agents. After 3 failed attempts, mark as blocked."

## Verification

1. `grep -c "^## Phase" skills/project-workflow-claude/SKILL.md` — 11 phases
2. `grep "FIRE ALL" skills/project-workflow-claude/SKILL.md` — parallel pattern present
3. `grep "run_in_background" skills/project-workflow-claude/SKILL.md` — background execution present
4. `grep "Workflow\|pre-flight" skills/project-workflow-claude/SKILL.md` — old Workflow references removed
5. `grep "haiku\|sonnet\|opus" skills/project-workflow-claude/SKILL.md` — tier routing present
6. `bash tests/test-workflow-changes.sh` — existing tests pass

## Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| All agents run same model tier (no classification) | LOW | Default 'sonnet' works for most tasks; tier routing is guidance |
| Collect step waits for all (slowest bottlenecks) | LOW | run_in_background makes each independent; failures don't block |
| OMC hook may still interrupt between agent launches | NONE | Agent calls don't trigger PreToolUse hook (already verified) |

# Plan: Project-Workflow Full Pipeline Smoke Test

**Goal**: Verify project-workflow v6.0 all phases execute correctly on Skills Repository.

**Context**:
- Type: Skills Repository (no go.mod, no package.json)
- Branch: main (30677a4)
- Go version: 1.25.7 (system, not project)

## Approach

Smoke-test each phase in order, with subagents for execution-heavy phases:

| Phase | Action | Executor |
|-------|--------|----------|
| 0 | Environment detect | Main |
| 0.3 | Skip (non-Go) | — |
| 0.5 | Skill selection | Subagent |
| 1 | Design spec | Main |
| 2 | Write plan (this file) | Main |
| 3 | Ralplan review | Subagent |
| 4 | Implement (no-op for test) | Main |
| 5 | Two-stage review | Subagent |
| 6 | Verified completion | Subagent |
| 7 | Retrospective | Subagent |
| 8 | Finish branch | Main |

## Files
- `.hermes/specs/2026-05-21-workflow-smoke-test-design.md` (created)
- `.hermes/plans/2026-05-21_120000-workflow-smoke-test.md` (this file)

## Verification
- Skills Repository Phase 6 checks:
  1. Phase count = 11 ✅
  2. YAML frontmatter valid ✅
  3. No MISSING/TODO/FIXME issues ✅
  4. git diff --check clean ✅
  5. All reference files exist ✅

## Risks
- None. Read-only verification, no code changes.

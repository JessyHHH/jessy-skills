# Design: Project-Workflow Full Pipeline Smoke Test

## Goal
Verify project-workflow v6.0 all phases (0→8) execute correctly on a Skills Repository.

## Scope
- **In**: Phase 0 (env), 0.5 (skills), 1 (design), 2 (plan), 3 (ralplan), 4 (impl), 5 (review), 6 (verify), 7 (retro), 8 (finish)
- **Out**: Modifying workflow logic, touching other skills
- **Non-goals**: Go build/test, code changes

## Constraints
- Skills Repository: no compiler, no tests, markdown-only
- Phase 6 verification uses Skills Repository commands (grep/YAML/git)

## Acceptance
- Each phase announces correctly
- Phase 6: all 5 Skills Repository checks PASS
- Phase 7: retrospective dispatched
- Phase 8: finish options presented

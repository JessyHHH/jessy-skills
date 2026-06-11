# Changelog

## v2.8 (2026-06-11)

### New Workflow Scripts
- **phase1-detect-knowledge.js**: Phase 1 Steps 5-7 — knowledge analysis + skill selection + context summary
- **phase2-plan-generate.js**: Phase 2 Steps 2-4 — plan generation + programmatic schema validation + context enrichment

### Phase 4 Completion Guarantee
- Stage 4 retry loop: max 3 internal retries for incomplete tasks
- Master-level compensation loop: max 2 retries with enriched context
- STUCK tasks returned with explicit stuckReason
- Token budget advisory: 50k tokens for retries

### Phase Boundaries State Validation
- Step 0 added to all 7 execution skills
- Required fields check per phase from `state-validation.md`
- `planning-implementation` entry guard: blocks when specPath+grillEvidencePath both null without "skip design" escape hatch
- `escapeHatchesUsed` array added to state file

### Context Dedup Phase 4→5
- `phase4-implement.js`: perTaskDiffs + fileContentsSnapshots in output
- Phase 5 already consumed these fields — zero changes to phase5-review.js
- ~30% token reduction for Phase 5 context loading

### Phase 6 Loop Contract
- `mandatoryNextAction` enum: RE_RUN_CHECKS / DONE
- `totalIterations` tracking with max 10 hard cap
- `verdict` field: PASSED / EXHAUSTED / IN_PROGRESS
- Dry-round logic unchanged (2 consecutive clean rounds)

### Documentation
- README.md updated to v2.8 with new features
- CHANGELOG.md created
- workflow-state-contract.md: version v2.7→v2.8, added escapeHatchesUsed

## v2.7 (2026-06-10)

### Modular Skills Architecture
- 1 thin orchestrator + 7 independent execution skills
- Each skill <500 lines with Exit Contract sections
- Handoff contract with auto-continue / prompt-next-step modes
- Escape hatches: skip design, skip plan, no review, I'll test, skip branch, skip workflow

### Per-Task Independent Pipeline
- Phase 5: spec→code→adversarial review per task, no inter-task blocking

### Tiered Models
- Haiku: spec/simplicity/final/adversarial
- Sonnet: correctness/safety
- ~60-70% token savings

### Context Injection + Anti-Exploration Guardrails
- Master agent pre-extracts spec sections and file contents into agent prompts
- Hard limits: 5 file reads max, no build/test/grep, max 3 thinking blocks

### Git-Diff Based Code Review
- Pre-computed diffs injected by master agent
- Reviewers only examine changed lines

## v2.6 (2026-05-28)

### Phase 5 Optimization
- Per-task pipeline: tasks flow independently spec→code→adversarial
- Tiered models: Haiku for simpler stages, Sonnet for deep reasoning
- Context injection: Master agent pre-digests context into agent prompts

## v2.4 (2026-05-15)

- Remove Opus from all Workflow subagents
- Phase 7.3 opt-in (memory compression cron)
- Explicit model declarations in all 17 subagents

## v2.3 (2026-05-01)

- Phase 1 Hard Grill Checklist (6 items)
- REQUIREMENT ECHO step
- Phase 5 Layered Review (4 complexity gates)
- Phase 4.6 Quick Gate
- Grill Evidence Persistence

## v2.2 (2026-04-15)

- CONTEXT.md dual-layer (Knowledge + Instruction)
- Phase 1 Deep Grill (Ambiguity Register + Assumption Ledger)
- Phase 0 Task Intake Snapshot
- Phase 4.5 Worktree Review
- Unified APPROVE/ITERATE/REJECT verdicts

# Golang Workflow Performance Benchmarks

Real-world timing data from v2.0 → v3.0 → v4.0 evolution tests.

## Test Environment
- **Model:** deepseek-v4-pro
- **Host:** macOS (26.3.1), Go 1.26.0
- **Docker:** golang:1.23-alpine (v2.0 test), golang:alpine/1.26.3 (v4.0 target)
- **delegate_task config:** max_concurrent_children=3, max_spawn_depth=1

## v2.0 — Full Deep Pipeline (Greenfield, 7 files, ~500 LOC)

| Phase | Duration | % | Notes |
|-------|----------|---|-------|
| 1: Deep Interview | ~3 min | 14% | 3 clarify rounds |
| 2: Ralplan (Planner) | 309s (5.2m) | 24% | 945-line plan, 24.8KB |
| 2: Ralplan (Architect) | 147s (2.5m) | 11% | Found 7 issues, 3 CRITICAL |
| 2: Ralplan (Critic) | 158s (2.6m) | 12% | Found amendments not applied |
| 3: Skill Routing | ~1 min | 5% | Loaded 4 skills |
| 4: Implementation | ~4 min | 18% | 7 files + go mod tidy |
| 5+6: Verify | ~2.2 min | 10% | 1 Ralph fix loop |
| **Total** | **~22 min** | 100% | |

## v3.0 — Quick Depth (Brownfield, 3 file patches, ~50 LOC)

| Phase | Duration | % | Notes |
|-------|----------|---|-------|
| 1: Deep Interview | 2 min | 25% | 2 clarify rounds |
| 2: Ralplan (Planner+SelfReview) | 130s (2.2m) | 27% | Merged, 159-line plan |
| 3: Skill Routing | 0 min | 0% | Pre-loaded, skipped |
| 4: Implementation | 1.5 min | 18% | 3 patches |
| 5+6: Verify | 1.6 min | 20% | 0 Ralph fix loops |
| **Total** | **~8.1 min** | 100% | |

**⚠️ UNFAIR COMPARISON: v2.0 was greenfield (7 new files), v3.0 was brownfield (3 patches).**  
Estimated ~7min of the 14min savings came from task simplicity, not optimization.

## v3.0 — Planner Benchmark (Same Task as v2.0)

| Metric | v2.0 | v3.0 (Planner+SelfReview) | Savings |
|--------|------|--------------------------|---------|
| Planner time | 309s | **212s** | -31% |
| Architect time | 147s | **0s** (merged) | -100% |
| Ralplan total | 456s | **212s** | **-53%** |
| Plan size | 945 lines | 364 lines | More concise |
| Issues found | 7 (Architect) | 6 risks + TOCTOU (Self-Review) | Comparable quality |

## v4.0 — Expected Performance (Estimated)

| Profile | Phases Active | Est. Time | vs v2.0 |
|---------|--------------|-----------|---------|
| Quick (simple task) | 0 → 0.5 → 1 → 2(Planner) → 3 → 4 → 5 → 6 | ~8 min | -64%* |
| Standard (default) | 0 → 0.5 → 1 → 2(P+S → Critic) → 3 → 4 → 5 → 6 | ~12 min | -45% |
| Deep (complex) | 0 → 0.5 → 1 → 2(P → A → C) → 3 → 4 → 5 → 6 | ~17 min | -23% |

*Note: v4.0 adds Phase 0 (env detection: ~30s) and Phase 0.5 (skill selection: ~10s).  
Phase 5 is now mandatory (adds ~1min vs v3.0 where it was sometimes skipped).  
Phase 6 adds govulncheck + modernize lint (adds ~30s).

## delegate_task Concurrency Model

- Uses `concurrent.futures.ThreadPoolExecutor` with `max_workers = delegation.max_concurrent_children` (default 3)
- Single tasks run directly on main thread (no thread pool overhead)
- Multiple tasks via `delegate_task(tasks=[...])` run in parallel threads
- **NOT serialized** — no internal mutex
- Sequential runs in the workflow are due to task dependencies (Architect needs Planner output), not tool limitation

## Key Bottleneck Findings

| Bottleneck | Impact | Mitigation |
|-----------|--------|-----------|
| delegate_task child startup | ~5-10s per call | Merge Planner+Architect (v3.0) |
| Deep Plans (945 lines) | High token cost | Quick depth mode for well-defined tasks |
| hermes chat -q background | Output fully buffered | Use cron jobs or in-session execution |
| Cron job deliver=local | No result visibility | Use in-session cron for test results |

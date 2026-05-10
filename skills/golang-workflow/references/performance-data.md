# Delegate Task Performance Data

Measured with `deepseek-v4-pro` model on macOS (Apple Silicon), Docker `golang:1.23-alpine`.

## Single delegate_task Timing

| Role | Task Size | Duration | Notes |
|------|----------|----------|-------|
| Planner (full plan) | 945-line plan, 12 tasks | ~309s | Creating bite-sized Go implementation plan from scratch |
| Architect (review) | Reading + reviewing 945-line plan | ~147s | Found 7 issues, 3 critical |
| Critic (validate) | Validating plan with amendments | ~158s | Found amendments not applied to code sketches |
| Planner+SelfReview (merged) | 159-line plan, 4 tasks | ~130s | v3.0 optimization: merged Planner+Architect |
| Code reviewer | Reviewing ~5 changed files | ~120-180s | Estimate (not measured in test) |

## Multi-Agent Pipeline (Serial)

| Pipeline | Total | Breakdown |
|----------|-------|-----------|
| v2.0 deep (Planner→Architect→Critic) | 614s (10.2 min) | 309+147+158 |
| v3.0 quick (Planner+SelfReview only) | 130s (2.2 min) | Single agent |
| v3.0 standard (Planner+SelfReview→Critic) | ~280s (4.7 min) | Estimate: 130+150 |

## End-to-End Workflow Timing

| Workflow Version | Task Type | Depth | Total Time |
|-----------------|-----------|-------|------------|
| v2.0 | Token bucket limiter (new project, 7 files) | deep | ~22 min |
| v3.0 | Health check endpoints (3 file patches) | quick | ~8.1 min |
| v3.0 | Medium complexity (estimate) | standard | ~12 min |
| v3.0 | High complexity (estimate) | deep | ~17 min |

## Phase Breakdown (v2.0 test)

| Phase | Time | % of Total |
|-------|------|-----------|
| 1: Deep Interview (3 clarify rounds) | ~3 min | 14% |
| 2: Ralplan (3 agents) | 12.5 min | 57% |
| 3: Skill Routing (load 4 skills) | ~1 min | 5% |
| 4: Implementation (7 files) | ~4 min | 18% |
| 5+6: Verify + Ralph loop | 2.2 min | 10% |

## Phase Breakdown (v3.0 quick test)

| Phase | Time | % of Total |
|-------|------|-----------|
| 1: Deep Interview (2 clarify rounds) | ~2 min | 25% |
| 2: Ralplan (1 agent) | 2.2 min | 27% |
| 3: Skill Routing (pre-loaded, skipped) | 0 min | 0% |
| 4: Implementation (3 file patches) | ~1.5 min | 18% |
| 5+6: Verify (no fixes needed) | 1.6 min | 20% |

## Key Insights

1. **Biggest bottleneck**: Serial delegate_task calls. Each spawns a fresh agent with 5-10s overhead.
2. **Merging Planner+Architect**: Saves 147s (71% reduction in planning phase). Self-review quality comparable to independent review for well-scoped tasks.
3. **Critic value**: Found "amendments not applied to code sketches" — valuable for complex plans, less so for simple ones.
4. **Pre-loaded skills**: Eliminated Phase 3 entirely (0s vs ~60s). The 5 core Go skills are sufficient for 80%+ of tasks.
5. **Ralph loop**: Both tests passed on first verification run. The Ralph loop is an insurance policy, not commonly exercised.

## Docker Go Testing Pattern

```bash
# Clean Go testing in Docker (macOS → Linux container)
docker run --rm -v "$PWD:/app" -w /app golang:1.23-alpine sh -c '
  go vet ./... && echo "vet: PASS"
  go test -count=1 ./... && echo "test: PASS"
  apk add --no-cache gcc musl-dev > /dev/null 2>&1  # for -race on alpine
  go test -race -count=1 ./... && echo "race: PASS"
  go build ./... && echo "build: PASS"
'
```

Note: `go test -race` on alpine requires `gcc` and `musl-dev` for CGO. Install with `apk add --no-cache`.

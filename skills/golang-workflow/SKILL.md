---
name: golang-workflow
description: "v4.0 Self-driving Golang workflow: environment detection → smart skill selection → deep-interview → write plan → ralplan → parallel impl → mandatory code-review → verified completion. Zero hardcoded skills. Go version auto-detected from go.mod or latest available."
version: "4.0"
author: "jessyhuang"
metadata:
  hermes:
    tags: [golang, workflow, meta-skill, auto-loaded, self-driving, smart]
    auto_load: true
---

# Golang Workflow v4.0 — Intelligent Self-Driving Pipeline

**Core design:** Zero pre-loaded skills (except `karpathy-guidelines`). Everything is context-detected: Go version, project type, codebase patterns, task signals. The agent adapts to the project, not the other way around.

**Self-driving:** Announce phases → execute → auto-transition. Never wait for user to say "next".

---

## Karpathy Enforcement (ALL phases, ALWAYS)

1. **Think Before Coding** — Assumptions stated. Tradeoffs surfaced. Confusion named.
2. **Simplicity First** — Minimum code. No speculative abstractions. Senior engineer would approve.
3. **Surgical Changes** — Only requested files. Match existing style. Every change traces to request.
4. **Goal-Driven Execution** — Success criteria defined BEFORE implementation. Verify with fresh evidence.

---

## Phase 0: Environment Detection (NEW — always first)

**Goal:** Know the project's Go version, dependency patterns, and available tooling before making any decisions.

**Procedure:**

1. **Go version detection:**
   - Check for `go.mod` → read `go` directive (e.g., `go 1.23`)
   - If `go.mod` exists: Docker image = `golang:<version>-alpine` (matches project)
   - If no `go.mod` (greenfield): `docker run --rm golang:alpine go version` → extract latest → use it
   - If no Go toolchain at all (not a Go project): skip all Go-specific phases, announce "Not a Go project — workflow inactive.", and answer normally with karpathy-guidelines only.
   - NEVER hardcode a Go version. Always detect.

2. **Project type detection:**
   - `search_files(pattern='go.mod', target='files')` → exists = brownfield, absent = greenfield
   - For brownfield: `search_files(pattern='*.go', target='files')` → map the codebase
   - Read key files to understand architecture: `read_file('go.mod')`, `read_file('main.go')` if exists

3. **Dependency pattern scanning** (brownfield only):
   ```
   search_files(pattern='github.com/samber/lo', target='content', file_glob='go.mod')  → samber/lo detected
   search_files(pattern='google.golang.org/grpc', target='content', file_glob='go.mod') → gRPC detected
   search_files(pattern='github.com/prometheus', target='content', file_glob='go.mod')  → Prometheus detected
   ```
   These signals feed Phase 0.5 skill selection.

4. **Tooling check:**
   - `which golangci-lint` → available or not
   - `which govulncheck` → available or not
   - If missing in Docker: `go install` them on demand

5. **Modernize Freshness Check** — ensure golang-modernize skill covers the detected Go version:
   a. Load golang-modernize via `skill_view(name='golang-modernize')`
   b. Extract the highest Go version from its "Go Version Changelogs" table (e.g., `Go 1.26`)
   c. Compare major.minor: if detected project Go version (e.g., `1.27`) > modernize's latest covered major.minor (e.g., `1.26`):
      - `web_search("Go <version> release notes new features standard library changes")`
      - `web_fetch("https://go.dev/doc/go<version>")` (e.g., `https://go.dev/doc/go1.27`)
      - Extract: new builtins, new packages, deprecated APIs, language changes, standard library additions
      - Update golang-modernize via `skill_manage(action='patch', name='golang-modernize', ...)`:
        - Append row to Go Version Changelogs table: `| Go 1.27 | August 2026 | https://go.dev/doc/go1.27 |`
        - Append relevant entries to Deprecated Packages Migration table
        - Append new high/medium/low priority items to Migration Priority Guide
        - Update Scope line: `...through Go 1.27...`
      - Announce: `"Updated golang-modernize with Go <version> features (N new entries)"`
   d. If detected version <= covered version: silent skip
   e. Pass any newly discovered features to Phase 0.5 baseline and Phase 5 modernization checklist

6. **Announce findings:**
   ```
   "Phase 0: Environment
   - Go: <version> (from go.mod / latest)
   - Modernize coverage: Go <latest covered> ✓ (up to date)
   - Docker: golang:<version>-alpine
   - Project: brownfield (go.mod found, N Go files)
   - Linter: golangci-lint available
   ```
   **Auto-transition to Phase 0.3.**

---

## Phase 0.3: Pre-Task Codebase Analysis (brownfield only)

**Goal:** Deeply understand the codebase before asking the user questions or planning changes. Ground all subsequent phases in real code, not assumptions.

**Trigger:** ALL of the following:
- Project is brownfield (has go.mod + Go files from Phase 0)
- The user sent a message requiring a response (not just a bare greeting like "hi"/"hello")
- Skip if: greenfield only — NO OTHER EXCEPTIONS

Phase 0.3 is MANDATORY for ALL brownfield questions. No "lightweight" bypass. No "general Go question" bypass. No "external topic" bypass. The agent cannot judge relevance without reading the codebase first — what looks like a general question may have project-specific context that completely changes the answer. This trigger fires for EVERY non-greeting message in a brownfield project.

**Procedure:**

1. Announce: "**Phase 0.3: Codebase Analysis** — understanding the project before proceeding."

2. Run analyze via `delegate_task`:
   ```
   delegate_task(
     goal="Deep read-only analysis of this Go codebase. Understand: architecture, key abstractions, data flow, error handling patterns, concurrency patterns, testing patterns. Identify confidence levels for each finding.",
     context="Project: <path from Phase 0>. Files: <list from Phase 0 file scan>. Task the user is asking about: <summary>. Produce: ranked synthesis with file references, evidence-vs-inference boundaries, confidence scores.",
     toolsets=["terminal", "file"]
   )
   ```

3. **Use analysis results to:**
   - Inform Phase 0.5 skill selection (e.g., "codebase uses samber/lo patterns" → auto-load golang-samber-lo)
   - Ground Phase 1 deep-interview questions in real code ("I see you have X pattern in Y file — should we follow that?")
   - Provide evidence-backed answers if the user just asked a question (not a change request)

4. If the user only asked a question (not a change request): present findings directly and STOP. Do not proceed to Phase 1.

5. If the user asked for changes: **Auto-transition to Phase 0.5.**

---

## Phase 0.5: Smart Skill Selection (NEW)

**Goal:** Select exactly the right skills for this task — no more, no less. No hardcoded pre-loads.

**Full routing table:** `references/golang-skill-routing.md` (task signals + codebase signals + common combos).

**Procedure:**

1. **Codebase signal matching** (from Phase 0 dependency scan):
   | Detected in go.mod / imports | Auto-select Skill |
   |-----------------------------|-------------------|
   | `google.golang.org/grpc` | `golang-grpc` |
   | `github.com/prometheus/client_golang` | (Prometheus patterns known, no separate skill needed) |
   | `github.com/samber/lo` | `golang-samber-lo` |
   | `github.com/samber/mo` | `golang-samber-mo` |
   | `github.com/samber/do` | `golang-samber-do` |
   | `github.com/samber/oops` | `golang-samber-oops` |
   | `github.com/samber/ro` | `golang-samber-ro` |
   | `database/sql` / `pgx` / `sqlx` | `golang-database` |
   | `github.com/stretchr/testify` | `golang-stretchr-testify` |
   | `cobra` / `urfave/cli` | `golang-cli` |
   | `go.uber.org/goleak` | (goleak patterns known) |
   | `log/slog` | (slog patterns known) |

2. **Task signal matching** (from user's initial request — Phase 1 deep-interview runs AFTER this phase and may refine selections later):
   | Task Keyword / Signal | Auto-select Skill |
   |----------------------|-------------------|
   | goroutine, channel, select, mutex, sync, race, concurrency, worker pool | `golang-concurrency` |
   | test, 测试, tdd, unit, integration, testify, mock, benchmark | `golang-testing` + `golang-stretchr-testify` (if testify detected) |
   | error, panic, recover, oops, fmt.Errorf, errors.Is | `golang-error-handling` |
   | refactor, 重构, rewrite, restructure, clean | `golang-code-style` + `golang-modernize` |
   | CLI, cobra, flag, command, 命令行 | `golang-cli` |
   | benchmark, 性能, profile, pprof, fast, slow | `golang-benchmark` + `golang-performance` |
   | lint, linter, golangci, vet, staticcheck | `golang-lint` |
   | context, ctx, timeout, deadline, cancel | `golang-context` |
   | security, 安全, vulnerability, injection, crypto | `golang-security` |
   | naming, 命名, convention, rename | `golang-naming` |
   | struct, interface, type, embed, receiver | `golang-structs-interfaces` |
   | database, sql, pg, mysql, sqlite, migration | `golang-database` |
   | DI, dependency injection, wire, fx, container | `golang-dependency-injection` |
   | pattern, 设计模式, functional options, builder | `golang-design-patterns` |
   | new project, init, layout, 项目结构 | `golang-project-layout` |
   | CI/CD, github actions, release, goreleaser | `golang-continuous-integration` |
   | grpc, protobuf, proto | `golang-grpc` |
   | log, observability, metric, trace, slog | `golang-observability` |
   | dependency, pkg, module, go.mod, upgrade | `golang-dependency-management` |
   | doc, comment, godoc, readme | `golang-documentation` |
   | library, 推荐, choose, pick | `golang-popular-libraries` |
   | slice, map, array, data structure, container | `golang-data-structures` |
   | debug, troubleshoot, bug, fix, 调试 | `golang-troubleshooting` |
   | defensive, safe, nil, panic prevention | `golang-safety` |
   | analyze, investigate, why does, what's causing, how does, codebase, understand, explain the code, 分析, 为啥, 为什么, 怎么工作, 怎么回事, what's going on, whats going on, what's happening, 弄清楚, 查一下原因, 帮我理解 | `analyze` |

3. **Modernize freshness trigger:** If Phase 0 freshness check discovered features for a Go version newer than the skill's table, **force-load** `golang-modernize` via `skill_view(name='golang-modernize')` regardless of task signals. New language features are essential context for all subsequent phases (planning, implementation, review, verification).

4. **Always-loaded baseline** (zero skill_view calls, just internalized rules):
   - `golang-modernize` principles: use `min`/`max`, `slog`, `t.Context()`, `b.Loop()`, `any`. Check `go.mod` version to know which features are available.
   - `golang-code-style` principles: functions <50 lines, no nested >4 levels, gofmt.
   - `golang-naming` principles: ErrNotFound, -er interfaces, ALL_CAPS acronyms.

5. **Load selected skills:** For each skill identified in steps 1-2, call `skill_view(name='<skill>')` to load its full content. Announce each loaded skill. Skip skills already internalized in baseline.

6. **Announce selection:**
   ```
   "Phase 0.5: Skills
   - Codebase signals: [testify detected] → golang-stretchr-testify
   - Task signals: [concurrency, testing, error handling] → 3 skills
   - Freshness check: [Go 1.27 features found] → golang-modernize force-loaded
   - Baseline: modernize + code-style + naming (internalized)
   - Total: 5 skills loaded"
   ```
   **Auto-transition to Phase 1.**

---

## Phase 1: Deep Interview (Mandatory)

**Goal:** Clarify intent, scope, non-goals, constraints, and acceptance criteria before any planning or coding.

**Procedure:**

1. Load the deep-interview skill: `skill_view(name='deep-interview')`
2. Announce: "**Phase 1: Deep Interview** — clarifying requirements."
3. Run a minimum of 3 `clarify()` rounds covering:
   - **Intent**: What are we actually trying to achieve? What problem does this solve?
   - **Scope**: What files/packages/modules are in scope? What's explicitly out of scope?
   - **Non-goals**: What are we deliberately NOT doing? (prevents scope creep)
   - **Constraints**: Go version, dependency versions, performance targets, compatibility requirements
   - **Acceptance**: How do we know it's done? Concrete, verifiable success criteria.
4. **Depth auto-selection** (from deep-interview skill):
   - **quick**: concrete files + function names + acceptance criteria already provided by user
   - **standard** (default): clear intent, medium complexity, some ambiguity to resolve
   - **deep**: auth/security, data migration, new architecture, breaking changes, multi-service coordination
5. Save key decisions to memory for cross-session persistence.
6. **Auto-transition to Phase 2.**

---

## Phase 2: Write Plan (NEW)

**Goal:** Produce a concrete, written implementation plan for ralplan consensus review. The plan lives in the project repo under `.hermes/plans/` so it persists across sessions and can be referenced by the ralplan critic.

**Procedure:**

1. Load the plan skill: `skill_view(name='plan')`
2. Announce: "**Phase 2: Write Plan** — writing plan to .hermes/plans/."
3. Write a plan following the plan skill format to `.hermes/plans/YYYY-MM-DD_HHMMSS-<slug>.md`:
   - **Goal**: What we're building — concise one-liner
   - **Context**: Go version, project type, key decisions from Phase 0 and Phase 1
   - **Approach**: Step-by-step implementation plan with exact file paths
   - **Files**: All files to create or modify, with expected changes per file
   - **Verification**: How we'll test each step (go build, go test, curl, etc.)
   - **Risks**: Known risks, tradeoffs, open questions
4. Save with `write_file` to `.hermes/plans/<timestamp>-<slug>.md`
5. Announce: "Plan saved to `.hermes/plans/<filename>.md`"
6. **Auto-transition to Phase 3.**

---

## Phase 3: Ralplan Consensus Planning

**Goal:** Produce a reviewed, critic-validated implementation plan before writing code.

**Procedure:**

1. Load the ralplan skill: `skill_view(name='ralplan')`
2. Announce: "**Phase 3: Ralplan Consensus Planning** — building implementation plan."
3. **Depth → agent configuration:**
   - **quick**: Planner subagent + SelfReview only
   - **standard**: Planner + SelfReview + Critic subagent
   - **deep**: Planner + SelfReview + Critic + full 3-agent consensus round
4. Planner MUST verify the Go version from Phase 0 is used in all commands and Docker references.
5. **Output:** A bite-sized task list with file paths, expected changes, and verification criteria per task.
6. Present the plan for user approval before proceeding.
7. **Auto-transition to Phase 4.**

---

## Phase 4: Consolidate Skills

All skills are now in context: the Phase 0.5 selected set + `deep-interview` (Phase 1) + `ralplan` (Phase 2). No additional skill loading needed — proceed directly to implementation.

---

## Phase 5: Implement (Ultrawork Parallel)

Parallel execution via `delegate_task(tasks=[...])`. For large-scale parallelism patterns, see `references/delegate-task-parallelism.md`.

**Auto-transition to Phase 6.**

---

## Phase 6: Mandatory Code Review (ALWAYS RUNS)

**This phase now ALWAYS executes.** Depth only affects scope, not whether it runs.

| Depth | Review Scope |
|-------|-------------|
| **quick** | git diff + concurrency safety + Go idioms + error handling |
| **standard** | quick scope + security scan + test coverage check |
| **deep** | standard scope + modernization audit + architecture consistency |

### Procedure:

1. `terminal('git diff --name-only')` → list changed files
2. `delegate_task(code-review)` with scope appropriate to depth
3. **Concurrency safety checklist** (always checked):
   - goroutine lifecycle: every goroutine has clear exit?
   - shared state: all protected by mutex/channel/atomic?
   - TOCTOU: gaps between check and action? (see `references/toctou-shutdown.md`)
   - channels: only sender closes? direction specified?
   - WaitGroup: Add() before go? sync.Once for shutdown?
4. **Modernization audit** (deep depth, or if go.mod >= 1.21):
   - Load `golang-modernize` via `skill_view(name='golang-modernize')` — use the version already loaded by Phase 0 freshness check or Phase 0.5; only reload if not in context
   - Run through golang-modernize's **Migration Priority Guide** (HIGH → MEDIUM → LOW) against ALL changed files
   - If Phase 0 freshness check discovered features for a Go version newer than golang-modernize's table, those items take priority
   - Flag every missed modernization opportunity with severity: `[HIGH]`, `[MEDIUM]`, `[LOW]`
   - Do NOT re-suggest items listed in the project's `.modernize` ignore file
5. Fix CRITICAL and HIGH before Phase 7. Re-review after fixes if substantial.
6. **Auto-transition to Phase 7.**

---

## Phase 7: Verified Completion (Enhanced)

Unchanged core: go mod tidy → go build → go vet → go test -race → benchmark.

**Verification steps:**

1. **go mod tidy** — ensures go.sum is clean, dependencies resolved
2. **go build ./...** — must exit 0
3. **go vet ./...** — no warnings
4. **go test -race -count=1 ./...** — ALL PASS
5. **govulncheck** (if available):
   ```
   go run golang.org/x/vuln/cmd/govulncheck@latest ./...
   ```
   Must show no known vulnerabilities.

6. **modernize linter** (if golangci-lint >= v2.6.0 and go.mod >= 1.21):
   ```
   golangci-lint run --enable-only modernize ./...
   ```
   Must show zero modernization warnings.

7. **Go version consistency check:**
   - Verify `go.mod` version matches the Docker image used
   - If greenfield: verify go.mod uses the latest detected version

8. **Ralph loop:** On any failure → fix → re-verify. Loop until ALL pass.

9. **Completion declaration** with evidence:
   ```
   "Verification complete:
   - go build: ✓
   - go vet: ✓
   - go test -race: ✓  (23/23 PASS)
   - govulncheck: ✓  (0 vulnerabilities)
   - modernize lint: ✓  (0 warnings)
   - benchmarks: ✓  (<1µs/op)"
   ```

---

## Self-Driving Transition Rules

| Phase | Auto-transition to | Condition |
|-------|-------------------|-----------|
| 0 (Environment) | 0.3 (Analyze) | Detection complete |
| 0.3 (Analyze) | 0.5 (Skills) | Analysis done (user asked for changes) OR skipped (greenfield only) |
| 0.5 (Skills) | 1 (Interview) | Skills selected |
| 1 (Interview) | 2 (Write Plan) | Clarity reached |
| 2 (Write Plan) | 3 (Ralplan) | Plan saved to .hermes/plans/ |
| 3 (Ralplan) | 4 (Consolidate) | Plan approved |
| 4 (Consolidate) | 5 (Implement) | Skills loaded |
| 5 (Implement) | 6 (Review) | All tasks done |
| 6 (Review) | 7 (Verify) | Issues fixed |
| 7 (Verify) | Done | ALL checks PASS |

---

## Escape Hatches

| Command | Effect |
|---------|--------|
| "quick" / "fast" | Force quick depth (lightweight interview + review) |
| "deep" / "careful" | Force deep depth (full review + modernization audit) |
| "skip interview" | Jump to Phase 2 (keep Phase 0/0.5) |
| "skip plan" | Jump to Phase 5 (keep Phase 6+7) |
| "no review" | Skip Phase 6 (DANGEROUS — use only for trivial changes) |
| "I'll test" | Skip Phase 7 verification |
| "FULL" | All phases with deep depth |

## References

- `references/golang-skill-routing.md` — Full routing table (task signals + codebase signals + common combos)
- `references/performance-benchmarks.md` — v2.0/v3.0/v4.0 timing data, delegate_task concurrency model, bottleneck findings
- `references/jessy-skills-setup.md` — Installing & syncing the jessy-skills Hermes dotfiles workflow across machines

---

## Anti-Patterns (NEVER)

1. ❌ Hardcode a Go version — always detect from go.mod or latest
2. ❌ Skip Phase 6 (code review) for non-trivial changes
3. ❌ Skip Phase 0 (environment detection) — leads to wrong Docker images
4. ❌ Use old Go version when go.mod specifies newer
5. ❌ Load all possible skills "just in case" — select based on signals
6. ❌ Declare done without go test -race output showing PASS
7. ❌ Skip the modernize freshness check — leads to missing new Go features when project uses a version beyond golang-modernize coverage

---
name: project-workflow
description: "v5.0 Generic self-driving project workflow: environment detection → smart skill selection → deep-interview → write plan → ralplan → parallel impl → mandatory code-review → verified completion. Zero hardcoded skills. Project type auto-detected from go.mod or latest available."
version: "5.1"
author: "jessyhuang"
metadata:
  hermes:
    tags: [golang, workflow, meta-skill, auto-loaded, self-driving, smart]
    auto_load: true
---

# Project Workflow v5.1 — Intelligent Self-Driving Pipeline

**Core design:** Zero pre-loaded skills (except `karpathy-guidelines`). Everything is context-detected: Go version, project type, codebase patterns, task signals. The agent adapts to the project, not the other way around.

**Self-driving:** Announce phases → execute → auto-transition. Never wait for user to say "next".

---

## Karpathy Enforcement (ALL phases, ALWAYS)

1. **Think Before Coding** — Assumptions stated. Tradeoffs surfaced. Confusion named.
2. **Simplicity First** — Minimum code. No speculative abstractions. Senior engineer would approve.
3. **Surgical Changes** — Only requested files. Match existing style. Every change traces to request.
4. **Goal-Driven Execution** — Success criteria defined BEFORE implementation. Verify with fresh evidence.
5. **Verify Before Asserting** — Search before claiming. For uncertain facts (library APIs, version differences, deprecated features, dependency compatibility), `web_search()` first. Don't guess. If results are ambiguous, state uncertainty explicitly.

---

## Phase 0: Environment Detection (always first)

**Goal:** Detect project type, language version, dependency patterns, and available tooling.

**Procedure:**

1. **Project type detection** (check in order, first match wins):
   - `search_files(pattern='go.mod', target='files')` → **Go project**
   - `search_files(pattern='package.json', target='files')` → check for Vue/React/Node:
     - `search_files(pattern='"vue"', target='content', file_glob='package.json')` → **Vue project**
     - `search_files(pattern='"react"', target='content', file_glob='package.json')` → **React project**
     - Otherwise → **Node/JavaScript project**
   - None of the above → **Unknown** (answer with karpathy-guidelines only)

2. **Language version detection:**
   - **Go:** read `go` directive from `go.mod`
   - **Vue/Node:** read `"vue"` or engines from `package.json`, check `tsconfig.json` for TypeScript

3. **Tooling check** (per project type):
   - **Go:** `which golangci-lint`, `which go`
   - **Vue/Node:** `which node`, `which npm`, `which pnpm`

4. **Dependency scanning** (brownfield only, per project type):
   - **Go:** scan `go.mod` for known patterns (samber, grpc, testify, etc.)
   - **Vue:** scan `package.json` for vue/pinia/vitest/vue-router

5. **Announce findings:**
   ```
   "Phase 0: Environment
   - Type: Go (go 1.25.3) / Vue (3.x + TypeScript) / Node
   - Skill pool: skills/go/ / skills/vue/
   - Tooling: go available / node available"
   ```
   **Auto-transition: Launch Phase 0.3 and Phase 0.5 in parallel.**
   - Phase 0.3: `delegate_task(analyze)` — runs in background
   - Phase 0.5: task signal matching + skill loading — runs concurrently
   - When both complete: Phase 0.5 augments from Phase 0.3 findings → Phase 1

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

## Phase 0.5: Smart Skill Selection 

**Goal:** Select exactly the right skills for this task — no more, no less. No hardcoded pre-loads.

**Full routing table:** `references/full-skill-routing.md` (task signals + codebase signals + common combos).

**Procedure:**

1. **Codebase signal matching** (from Phase 0 dependency scan):
   - **Go:** scan `go.mod` for known patterns (samber, grpc, testify, etc.) → see `references/full-skill-routing.md`
   - **Vue:** scan `package.json` for vue/pinia/vitest/vue-router → see `references/full-skill-routing.md`

2. **Task signal matching** (from user's initial request):
   - Match keywords against `references/full-skill-routing.md` — covers all 59 skills across Go, Vue, Frontend, and Engineering categories.
   - Also scan for self-learning triggers: if the user mentions "performance" with an error tone, preload `golang-benchmark`; if they mention repeated failures, preload `diagnose`.

3. **Modernize freshness trigger:** (Go only) If Phase 0 freshness check discovered features for a Go version newer than the skill's table, **force-load** `golang-modernize`.

4. **Always-loaded baseline** (zero skill_view calls, just internalized rules):
   - `golang-modernize` principles: use `min`/`max`, `slog`, `t.Context()`, `b.Loop()`, `any`. Check `go.mod` version (Go projects only).

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

7. **Augment from Phase 0.3 findings** (runs after Phase 0.3 completes):
   - Phase 0.3 runs in parallel with the selection above. When it finishes, scan its analysis output for codebase patterns not yet covered (samber, gRPC, database, concurrency patterns).
   - Diff against already-loaded skills. Load missing ones via `skill_view(name='...')`.
   - Silent skip if nothing new. Announce any additions.

8. **Auto-transition to Phase 1.**

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
6. **Skill Re-Check** (runs after interview completes):
   - **Re-scan codebase signals** against `references/full-skill-routing.md`
   - **Re-scan task signals** from all `clarify()` results + conversation context
   - **Diff** against Phase 0.5 loaded skills. Load missing via `skill_view()`.
   - **Announce** additions (silent skip if nothing new).
7. **Auto-transition to Phase 2.**

---

## Phase 2: Write Plan 

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
6. **Post-Plan Skill Check** (runs immediately after plan is written):
   - Read the plan file
   - Scan for technical signals using `references/full-skill-routing.md` (all 59 skills)
   - **Diff** against already-loaded skills (Phase 0.5 + Phase 1 re-check)
   - **Load missing** via `skill_view()`. Announce additions (silent skip if nothing new)
7. **Auto-transition to Phase 3.**

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


## Phase 4: Implement (Ultrawork Parallel)

Parallel execution via `delegate_task(tasks=[...])`. For large-scale parallelism patterns, see `references/delegate-task-parallelism.md`.

**Auto-transition to Phase 5.**

---

## Phase 5: Mandatory Code Review (ALWAYS RUNS)

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
5. Fix CRITICAL and HIGH before Phase 6. Re-review after fixes if substantial.
6. **Auto-transition to Phase 6.**

---

## Phase 6: Verified Completion

**Goal:** Language-appropriate build, test, lint, and security verification.

**Verification routing (by project type detected in Phase 0):**

### Go
1. `go mod tidy` — clean go.sum
2. `go build ./...` — must exit 0
3. `go vet ./...` — no warnings
4. `go test -race -count=1 ./...` — ALL PASS
5. `go run golang.org/x/vuln/cmd/govulncheck@latest ./...` — 0 vulnerabilities
6. `golangci-lint run --enable-only modernize ./...` — 0 warnings

### Vue / Node
1. `npm ci` (or `pnpm install`) — clean deps
2. `npx tsc --noEmit` (if TypeScript) — no type errors
3. `npm test` (or `npx vitest run`) — ALL PASS
4. `npm run lint` (if configured) — 0 warnings
5. `npm audit` — 0 critical vulnerabilities

**Ralph loop:** On any failure → fix → re-verify. Loop until ALL pass.

**Completion declaration:**
```
"Verification complete:
- <lang> build: ✓
- <lang> test: ✓  (N/N PASS)
- lint: ✓  (0 warnings)
- security: ✓  (0 vulnerabilities)"
```

---

## Phase 7: Retrospective & Learn (always last, runs in background)

**Goal:** After every session, launch a subprocess to reflect, extract lessons, save to durable memory, and suggest skill improvements — while the main agent stays responsive.

**Trigger:** Phase 7 completed.

**Procedure:**

1. **Launch retrospective in subprocess:**
   ```
   delegate_task(
     goal="Phase 7 Retrospective. Scan this session: errors, user corrections, skill misses, patterns. Extract lessons. Save to memory(). Output retrospective report.",
     context="Session summary: <key events, failures, corrections, skills loaded>",
     toolsets=["terminal","file","skills"]
   )
   ```
   The subprocess runs asynchronously. Main agent continues immediately.

2. **Self-Learning (inline checks, runs before delegate_task dispatch):**
   | Trigger | Action |
   |---------|--------|
   | Phase 6 failed >3 times on same issue | Auto-load `diagnose` + relevant debug skill |
   | Phase 6 found >5 modernization warnings | Force-load `golang-modernize` for next cycle |
   | User corrected same pattern ≥2 times | Save to `memory` as durable preference |
   | Plan missed a relevant skill | Phase 2 post-plan check catches. Update routing table if repeated |
   | Performance degradation detected | Load relevant performance/benchmark skill |

3. **Transition:** Done immediately. Retrospective completes in background.

---

## Self-Driving Transition Rules

| Phase | Auto-transition to | Condition |
|-------|-------------------|-----------|
| 0 (Environment) | 0.3 + 0.5 (parallel) | Detection complete — launch both simultaneously |
| 0.3 + 0.5 (done) | 1 (Interview) | 0.3 analysis complete + 0.5 skills loaded + augment done |
| 1 (Interview) | 2 (Write Plan) | Clarity reached + skill re-check done |
| 2 (Write Plan) | 3 (Ralplan) | Plan saved + post-plan skill check done |
| 3 (Ralplan) | 4 (Implement) | Plan approved |
| 4 (Implement) | 5 (Review) | All tasks done |
| 5 (Review) | 6 (Verify) | Issues fixed |
| 6 (Verify) | 7 (Retro) | ALL checks PASS → Phase 7 background |
| 7 (Retro) | Done | Retrospective dispatched. Main agent free. |

---

## Escape Hatches

| Command | Effect |
|---------|--------|
| "quick" / "fast" | Force quick depth (lightweight interview + review) |
| "deep" / "careful" | Force deep depth (full review + modernization audit) |
| "skip interview" | Jump to Phase 2 (keep Phase 0/0.5) |
| "skip plan" | Jump to Phase 4 (keep Phase 5+6) |
| "no review" | Skip Phase 6 (DANGEROUS — use only for trivial changes) |
| "I'll test" | Skip Phase 6 verification |
| "FULL" | All phases with deep depth |

- `references/full-skill-routing.md` — Complete 59-skill routing table (Go + Vue + Frontend + Engineering + plan-specific)
- `references/full-skill-routing.md` — 
- `references/performance-benchmarks.md` — v2.0/v3.0/v4.0 timing data

---

## Anti-Patterns (NEVER)

1. ❌ Hardcode a Go version — always detect from go.mod or latest
2. ❌ Skip Phase 6 (code review) for non-trivial changes
3. ❌ Skip Phase 0 (environment detection) — leads to wrong Docker images
4. ❌ Use old Go version when go.mod specifies newer
5. ❌ Load all possible skills "just in case" — select based on signals
6. ❌ Declare done without go test -race output showing PASS
7. ❌ Skip the modernize freshness check — leads to missing new Go features when project uses a version beyond golang-modernize coverage
8. ❌ Skip Phase 3 plan review and jump straight to implementation — present the plan, WAIT for user to say "确认"/"执行"/"改"/"开始" before touching code, then execute. The confirmation step is NOT optional — even for small changes. Ending the plan presentation with "确认后执行" and waiting for the actual response word is mandatory. Do NOT auto-transition past this gate without user sign-off.
9. ❌ Skip Phase 6+7 (code review + verification) after any code change — always run go build + go vet + go test -race. After batch changes, announce which group completed, present verification output explicitly, then proceed to next group.
10. ❌ Fuse Phase 2 (plan writing) into Phase 3 (ralplan presentation) — they are separate steps
11. ❌ Present plan inline without writing it to `.hermes/plans/` first — Phase 2 requires a saved plan file before Phase 3 presentation

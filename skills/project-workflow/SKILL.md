---
name: project-workflow
description: "v5.0 Generic self-driving project workflow: environment detection → smart skill selection → deep-interview → write plan → ralplan → parallel impl → mandatory code-review → verified completion. Zero hardcoded skills. Project type auto-detected from go.mod or latest available."
version: "6.0"
author: "jessyhuang"
metadata:
  hermes:
    tags: [golang, workflow, meta-skill, auto-loaded, self-driving, smart]
    auto_load: true
---

# Project Workflow v6.0 — Intelligent Self-Driving Pipeline with Hard Gates

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
   - `search_files(pattern='SKILL.md', target='files', path='skills/')` returns matches → **Skills Repository** (text-only meta project)
   - None of the above → **Unknown** (answer with karpathy-guidelines only)

2. **Language version detection:**
   - **Go:** read `go` directive from `go.mod`
   - **Vue/Node:** read `"vue"` or engines from `package.json`, check `tsconfig.json` for TypeScript
   - **Skills Repository:** no language version — text-only project

3. **Tooling check** (per project type):
   - **Go:** `which golangci-lint`, `which go`
   - **Vue/Node:** `which node`, `which npm`, `which pnpm`
   - **Skills Repository:** no build tooling needed — `which git` only

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

5.5. **Memory trigger detection:**
   - Scan current `memory` for trigger entries matching the pattern: `→ 加载 skill <name>`
   - For each matched skill name, call `skill_view(name='<name>')` to load the compressed knowledge back into context
   - This ensures knowledge archived by Phase 7.3's compression cycle is automatically available in new sessions
   - Skip skills already loaded in step 5

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

## Phase 1: Design First (HARD-GATE)

<HARD-GATE>
在用户批准设计方案之前，禁止调用任何 implementation skill、写任何代码、创建任何项目脚手架。
适用于所有项目，不论多简单。简单项目的设计可以很短（几句话），但必须呈现并获批准。
</HARD-GATE>

**Goal:** Turn ideas into fully formed designs through collaborative dialogue. Present 2-3 approaches with tradeoffs, write a design spec, and get user approval before any planning or coding.

**Anti-pattern:** "太简单不需要设计" — 简单项目才是未经审视的假设浪费最多工作量的时候。

**Procedure:**

1. Announce: "**Phase 1: Design First** — exploring approaches before implementation."

2. **Explore project context** — check files, docs, recent commits (Phase 0/0.3 already covered this)

3. **Ask clarifying questions** — one at a time, understand purpose/constraints/success criteria:

   <BOUNDARY-CHECK>
   第一轮 clarify 必须确认项目边界。在问其他问题之前，必须先明确：
   - 涉及哪些文件/包/模块/服务？
   - 明确 NOT 涉及哪些？（防止 scope creep）
   - 如果有任何歧义：向用户确认边界后再继续。
   未经边界确认，禁止进入步骤 4（方案设计）。
   </BOUNDARY-CHECK>

   - **Intent**: What are we actually trying to achieve? What problem does this solve?
   - **Scope**: What files/packages/modules are in scope? What's explicitly out of scope?
   - **Non-goals**: What are we deliberately NOT doing?
   - **Constraints**: Go version, dependency versions, performance targets, compatibility requirements
   - **Acceptance**: How do we know it's done? Concrete, verifiable success criteria.
   - Prefer multiple choice questions when possible. Only one question per message.

4. **Propose 2-3 approaches** — with trade-offs and your recommendation:
   - Lead with your recommended option and explain why
   - Present tradeoffs honestly: what each approach gains and costs

5. **Present design** — in sections scaled to their complexity:
   - Cover: architecture, components, data flow, error handling, testing
   - Get user approval after each section
   - Simple project: a few sentences. Complex project: 200-300 words per section.

6. **Write design spec** — save to `.hermes/specs/YYYY-MM-DD-<topic>-design.md` and commit

7. **Spec self-review** — check for placeholders, contradictions, ambiguity, scope:
   - Any "TBD", "TODO", incomplete sections? Fix them.
   - Do any sections contradict each other?
   - Is the scope focused enough for a single implementation plan?
   - Could any requirement be interpreted two different ways? Pick one and make it explicit.

8. **User reviews written spec** — ask user to review the spec file before proceeding:
   > "Spec written to `.hermes/specs/<file>`. Please review and let me know if changes needed before we write the implementation plan."

9. **Skill Re-Check** (runs after design approved):
   - **Re-scan codebase signals** against `references/full-skill-routing.md`
   - **Re-scan task signals** from all `clarify()` results + conversation context
   - **Diff** against Phase 0.5 loaded skills. Load missing via `skill_view()`.

10. **Auto-transition to Phase 2** — invoke `skill_view(name='plan')` and write implementation plan.

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

## Phase 5: Two-Stage Review (ALWAYS RUNS)

**This phase now ALWAYS executes.** Two stages in fixed order: spec compliance first, then code quality.

**Core principle:** Spec compliance review MUST complete with ✅ before code quality review begins. Never skip stages or reverse order.

### Stage 1: Spec Compliance Review

Check code against the plan/spec from Phase 2-3. Does the implementation match what was designed?

1. `terminal('git diff --name-only')` → list changed files
2. Re-read the plan file from `.hermes/plans/` (saved in Phase 2)
3. Run spec compliance via `delegate_task`:
   ```
   delegate_task(
     goal="Spec compliance review. Compare implementation against plan. Check: all planned tasks done? extra work not in plan? requirements all met?",
     context="Plan: <summary>. Changed files: <list>.",
     toolsets=["terminal","file"]
   )
   ```
4. **Gate:** Only proceed to Stage 2 when spec compliance is ✅
   - ❌ Issues found → fix → re-review → repeat until ✅
   - Never accept "close enough" — spec reviewer found issues = not done

### Stage 2: Code Quality Review

| Depth | Review Scope |
|-------|-------------|
| **quick** | git diff + concurrency safety + Go idioms + error handling |
| **standard** | quick scope + security scan + test coverage check |
| **deep** | standard scope + modernization audit + architecture consistency |

**Procedure:**

1. `delegate_task(code-review)` with scope appropriate to depth
2. **Concurrency safety checklist** (always checked):
   - goroutine lifecycle: every goroutine has clear exit?
   - shared state: all protected by mutex/channel/atomic?
   - TOCTOU: gaps between check and action? (see `references/toctou-shutdown.md`)
   - channels: only sender closes? direction specified?
   - WaitGroup: Add() before go? sync.Once for shutdown?
3. **Modernization audit** (deep depth, or if go.mod >= 1.21):
   - Load `golang-modernize` via `skill_view(name='golang-modernize')` — use the version already loaded by Phase 0 freshness check or Phase 0.5; only reload if not in context
   - Run through golang-modernize's **Migration Priority Guide** (HIGH → MEDIUM → LOW) against ALL changed files
   - If Phase 0 freshness check discovered features for a Go version newer than golang-modernize's table, those items take priority
   - Flag every missed modernization opportunity with severity: `[HIGH]`, `[MEDIUM]`, `[LOW]`
   - Do NOT re-suggest items listed in the project's `.modernize` ignore file
4. Fix CRITICAL and HIGH before Phase 6. Re-review after fixes if substantial.

**Red Flags (NEVER):**
- Start code quality review before spec compliance is ✅ (wrong order)
- Skip either stage
- Move to next task while either review has open issues
- Accept "close enough" on spec compliance

6. **Auto-transition to Phase 6.**

---

## Phase 6: Verified Completion (Iron Law)

### The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always. If you haven't run the verification command in this message, you cannot claim it passes.

### The Gate Function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

### Red Flags — STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!")
- About to commit/push/PR without verification
- Trusting subagent success reports
- Relying on partial verification
- Thinking "just this once"
- **ANY wording implying success without having run verification**

### Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter ≠ compiler |
| "Subagent said success" | Verify independently |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter |

### Verification Routing (by project type detected in Phase 0)

**Go**
1. `go mod tidy` — clean go.sum
2. `go build ./...` — must exit 0
3. `go vet ./...` — no warnings
4. `go test -race -count=1 ./...` — ALL PASS
5. `go run golang.org/x/vuln/cmd/govulncheck@latest ./...` — 0 vulnerabilities
6. `golangci-lint run --enable-only modernize ./...` — 0 warnings

**Vue / Node**
1. `npm ci` (or `pnpm install`) — clean deps
2. `npx tsc --noEmit` (if TypeScript) — no type errors
3. `npm test` (or `npx vitest run`) — ALL PASS
4. `npm run lint` (if configured) — 0 warnings
5. `npm audit` — 0 critical vulnerabilities

**Skills Repository**
1. `grep -c "^## Phase" skills/project-workflow/SKILL.md` → Phase 数一致
2. `head -15 skills/*/SKILL.md` (抽查) → YAML frontmatter 合法
3. `grep -rn "MISSING\|✗\|TODO\|FIXME" skills/` → 0 未解决的问题
4. `git diff --check` → 无 whitespace 错误
5. `for ref in $(grep -oP 'references/[a-z0-9-]+\.md' SKILL.md); do test -f "$ref" && echo "✓" || echo "✗"; done` → 所有引用文件存在

**Ralph loop:** On any failure → fix → re-verify. Loop until ALL pass.

### Completion Declaration (with evidence)

```
"Verification complete:
- <lang> build: ✓  (exit 0)
- <lang> test: ✓  (N/N PASS)
- lint: ✓  (0 warnings)
- security: ✓  (0 vulnerabilities)
- requirements: ✓  (N/N checklist items verified)"
```

---

## Phase 7: Retrospective & Learn + Memory Cron (always last, runs in background)

**Goal:** Three-layer learning system: session-end reflection (7.1), inline self-learning (7.2), and persistent cross-session memory cron with auto-compression (7.3).

**Trigger:** Phase 6 completed.

---

### 7.1 Session-End Retrospective

Launch a subprocess to reflect on the current session, extract lessons, save to durable memory, and suggest skill improvements — while the main agent stays responsive.

```
delegate_task(
  goal="Phase 7.1 Retrospective. Scan this session: errors, user corrections, skill misses, patterns. Extract lessons. Save to memory(). Output retrospective report.",
  context="Session summary: <key events, failures, corrections, skills loaded>",
  toolsets=["terminal","file","skills"]
)
```

The subprocess runs asynchronously. Main agent continues immediately.

---

### 7.2 Self-Learning (inline checks)

Runs inline before 7.1 dispatch:

| Trigger | Action |
|---------|--------|
| Phase 6 failed >3 times on same issue | Auto-load `diagnose` + relevant debug skill |
| Phase 6 found >5 modernization warnings | Force-load `golang-modernize` for next cycle |
| User corrected same pattern ≥2 times | Save to `memory` as durable preference |
| Plan missed a relevant skill | Phase 2 post-plan check catches. Update routing table if repeated |
| Performance degradation detected | Load relevant performance/benchmark skill |

---

### 7.3 Background Memory Cron ★ NEW v5.2

**Goal:** A persistent cron job (every 2 hours) that does cross-session pattern extraction and, when memory is ≥90% full, auto-compresses memory into topic-based skills.

**Cron job management** (runs once when workflow loads):

```
# Check if cron job already exists (idempotent)
cronjob(action='list') → scan for 'hermes-phase7-memory-cron'
IF not found:
  cronjob(
    action='create',
    name='hermes-phase7-memory-cron',
    schedule='every 2h',
    prompt="Phase 7.3 Memory Cron. Run the COMPRESS_OR_EXTRACT algorithm below. Use session_search to scan recent sessions. Use memory to check usage and read/write entries. Use skill_manage to create/patch memory-backup skills.",
    skills=['project-workflow'],
    toolsets=['session_search', 'skills']
  )
IF found and schedule differs:
  cronjob(action='update', job_id='<id>', schedule='every 2h')
```

#### COMPRESS_OR_EXTRACT Algorithm

```
1. session_search(query='', limit=5) → get recent session summaries
2. Read current memory usage from conversation context（检查 prompt 头部 MEMORY 行的使用率百分比，如 `[96% — 2,122/2,200 chars]`）
3. IF memory ≥ 90%:
     RUN COMPRESSION CYCLE
   ELSE:
     RUN CROSS-SESSION EXTRACTION
```

#### COMPRESSION CYCLE (memory ≥ 90%)

```
1. Read ALL memory entries (both 'memory' and 'user' stores)
2. Classify by topic using LLM:
   - Group related entries (e.g., all yunuop conventions, all mixgo constraints, all Go patterns)
   - Each group becomes a candidate skill
3. FOR EACH topic group:
   a. Summarize into 3-5 concise, impactful rules
   b. Name: memory-<topic-slug> (e.g., memory-yunuop, memory-mixgo, memory-golang)
   c. Category: project/memory-backup/
   d. Check if skill already exists:
      - EXISTS → skill_manage(action='patch') — append new rules without duplicating
      - NOT EXISTS → skill_manage(action='create') — full SKILL.md with frontmatter
   e. If skill exceeds 300 lines → split: create memory-<topic>-part2, etc.
4. REPLACE memory entries:
   - Remove all detailed entries that were classified into skills
   - Write compact trigger entries:
     "<topic>: 加载 skill memory-<topic-slug>"
   - Trigger format MUST be machine-parseable by Phase 0.5 step 5.5
5. Verify: memory usage dropped by ≥30% from pre-compression level
6. If still ≥90% after first pass → run a second pass with more aggressive summarization
```

#### CROSS-SESSION EXTRACTION (memory < 90%)

```
1. session_search() → scan recent sessions for recurring patterns
2. Identify patterns that appear across ≥2 sessions
3. IF new durable convention found:
     memory(action='add', target='memory', content='<convention>')
4. IF existing convention contradicted:
     memory(action='replace', old_text='<old>', content='<new>')
5. IF stale convention (not referenced in last 10 sessions):
     memory(action='remove', old_text='<stale>')
```

#### Trigger Format Specification

Compressed memory triggers must follow this exact format so Phase 0.5 can parse them:

```
<topic>: 加载 skill <skill-name>
```

Example:
```
yunuop: 加载 skill memory-yunuop
mixgo: 加载 skill memory-mixgo
golang: 加载 skill memory-golang
```

Phase 0.5 step 5.5 scans for `加载 skill <name>` pattern and auto-loads the referenced skill.

#### Generated Skill Format

```yaml
---
name: memory-<topic-slug>
description: "Compressed memory backup — <topic> conventions and lessons. Auto-generated by Phase 7.3 Memory Cron."
version: "1.0"
category: project/memory-backup
---

# Memory Backup: <Topic>

Auto-generated from compressed agent memory. Loaded automatically by Phase 0.5 trigger detection.

## Key Rules

1. <rule 1>
2. <rule 2>
3. <rule 3>
...
```

---

3. **Transition:** 7.1 + 7.2 dispatched immediately. 7.3 cron runs independently every 2h.

---

## Phase 8: Finish Branch ★ NEW v6.0

**Goal:** Structured completion of development work. Verify tests → detect environment → present options → execute choice → clean up.

**Core principle:** Verify tests → Detect environment → Present options → Execute choice → Clean up.

**Announce at start:** "**Phase 8: Finish Branch** — completing development work."

### Step 1: Final Verification

Before presenting options, run the project's test suite one final time:

```bash
# Go
go test -race -count=1 ./...

# Vue/Node
npm test  # or npx vitest run
```

**If tests fail:** Stop. Fix before proceeding. Cannot complete with failing tests.

**If tests pass:** Continue to Step 2.

### Step 2: Detect Environment

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

| State | Menu | Cleanup |
|-------|------|---------|
| `GIT_DIR == GIT_COMMON` (normal repo) | Standard 4 options | No worktree |
| `GIT_DIR != GIT_COMMON`, named branch | Standard 4 options | Provenance-based |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 3 options (no merge) | Externally managed |

### Step 3: Determine Base Branch

```bash
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main — is that correct?"

### Step 4: Present Options

**Normal repo and named-branch: exactly 4 options:**

```
Implementation complete. Verified:
- Tests: N/N PASS
- Lint: clean
- Build: ✓

What would you like to do?

1. Merge to <base> locally
2. Push and create a Pull Request
3. Keep the branch as-is
4. Discard this work

Which option?
```

**Detached HEAD: exactly 3 options (no local merge):**

```
Implementation complete. You're on a detached HEAD (externally managed).

1. Push as new branch and create a Pull Request
2. Keep as-is
3. Discard this work

Which option?
```

### Step 5: Execute Choice

#### Option 1: Merge Locally
```bash
git checkout <base-branch>
git pull
git merge <feature-branch>
<test command>  # verify merged result
git branch -d <feature-branch>
```

#### Option 2: Push and Create PR
```bash
git push -u origin <feature-branch>
gh pr create --title "<title>" --body "<summary>"
```
Do NOT clean up worktree — user needs it for PR iteration.

#### Option 3: Keep As-Is
Report: "Keeping branch <name>. Worktree preserved."

#### Option 4: Discard
Require typed confirmation ("discard"). Then:
```bash
git branch -D <feature-branch>
```

### Step 6: Cleanup

Only for Options 1 and 4. Options 2 and 3 preserve workspace.

- Normal repo: no worktree to clean
- Worktree-owned: `git worktree remove <path> && git worktree prune`

### Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | yes | - | - | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| 4. Discard | - | - | - | yes (force) |

### Red Flags (NEVER)
- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without typed "discard" confirmation
- Clean up worktrees for Options 2 or 3
- Skip test verification before offering options

---

## Self-Driving Transition Rules

| Phase | Auto-transition to | Condition |
|-------|-------------------|-----------|
| 0 (Environment) | 0.3 + 0.5 (parallel) | Detection complete — launch both simultaneously |
| 0.3 + 0.5 (done) | 1 (Design First) | 0.3 analysis complete + 0.5 skills loaded + augment done |
| 1 (Design First) | 2 (Write Plan) | Design approved + spec written + user reviewed |
| 2 (Write Plan) | 3 (Ralplan) | Plan saved + post-plan skill check done |
| 3 (Ralplan) | 4 (Implement) | Plan approved |
| 4 (Implement) | 5 (Two-Stage Review) | All tasks done |
| 5 (Two-Stage Review) | 6 (Verify) | Both stages pass — spec ✅ then code ✅ |
| 6 (Verify) | 7 (Retro + Cron) | ALL checks PASS with fresh evidence |
| 7 (Retro + Cron) | 8 (Finish Branch) | 7.1 + 7.2 dispatched; 7.3 cron runs independently |
| 8 (Finish Branch) | Done | Branch merged/PR created/kept/discarded per user choice |

---

## Escape Hatches

| Command | Effect |
|---------|--------|
| "quick" / "fast" | Force quick depth (lightweight interview + review) |
| "deep" / "careful" | Force deep depth (full review + modernization audit) |
| "skip design" | Jump to Phase 2 (keep Phase 0/0.5) |
| "skip plan" | Jump to Phase 4 (keep Phase 5+6) |
| "no review" | Skip Phase 6 (DANGEROUS — use only for trivial changes) |
| "I'll test" | Skip Phase 6 verification |
| "skip branch" | Skip Phase 8 (Finish Branch) |
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

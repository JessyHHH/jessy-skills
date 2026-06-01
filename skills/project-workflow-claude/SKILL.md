---
name: project-workflow-claude
description: "v1.0 Self-driving 11-phase pipeline for Claude Code. Auto-detect project type → load matching skills → design→plan→implement→review→verify. Hard Gates + Iron Law. Requires OMC for ralph/ralplan."
version: "v1.0"
author: "jessyhuang"
metadata:
  requires: [oh-my-claudecode]
  fallback: "Phase 3 uses simplified inline consensus review. Phase 6 uses manual verify-fix loop."
---

# Project Workflow Claude v1.0 — Self-Driving Pipeline with Hard Gates

**Core design:** Zero pre-loaded skills (except `karpathy-guidelines`). Everything is context-detected: Go version, project type, codebase patterns, task signals. Uses Claude Code native tools — `Workflow`, `Agent`, `Skill`, `Glob`, `Grep`, `Bash`, `AskUserQuestion`, `CronCreate`.

**Self-driving:** Announce phases → execute → auto-transition. Never wait for user to say "next".

**Platform:** Claude Code v2.1+ with OMC (oh-my-claudecode) v4.14+. Phases 3/6 use OMC's `ralplan`/`ralph`. Fallback available without OMC.

---

## OMC Compliance — Delegation Rules (MANDATORY)

Under OMC, the master agent CANNOT directly Write/Edit files in the working project. The PreToolUse hook WILL block these operations. ALL file modifications MUST be delegated to subagents.

| Operation | Who | Tool |
|-----------|-----|------|
| Read, search, plan, design | Master agent | Read, Glob, Grep, AskUserQuestion |
| Skill loading | Master agent | Skill |
| Shell commands (Bash) | Master agent | Bash |
| CRITICAL: File writing | Subagent ONLY | Agent(general-purpose) |
| Multi-file implementation | Subagent pipeline | Workflow or Agent |
| Knowledge/spec/plan file write | Subagent | Agent(general-purpose) |

SELF-CHECK before EVERY Write/Edit call:
"If I am the master agent → STOP. Delegate to Agent subagent instead."

NEVER use Bash(sed -i) to edit files — it bypasses the hook but causes silent errors. If Write/Edit is needed, use Agent subagent.

---

## Karpathy Enforcement (ALL phases, ALWAYS)

1. **Think Before Coding** — Assumptions stated. Tradeoffs surfaced. Confusion named.
2. **Simplicity First** — Minimum code. No speculative abstractions.
3. **Surgical Changes** — Only requested files. Match existing style.
4. **Goal-Driven Execution** — Success criteria defined BEFORE implementation. Verify with fresh evidence.
5. **Verify Before Asserting** — Use `prior-research` chain (ctx7 → firecrawl → WebSearch). Don't guess.

---

## Phase 0: Environment Detection (always first)

**Goal:** Detect project type, language version, dependency patterns, and available tooling.

**Procedure:**

1. **Project type detection** (check in order, first match wins):
   - `Glob(pattern='**/go.mod')` returns matches → **Go project**
   - `Glob(pattern='**/package.json')` returns matches → check for Vue/React:
     - `Grep(pattern='"vue"', path='package.json')` → **Vue project**
     - `Grep(pattern='"react"', path='package.json')` → **React project**
     - Otherwise → **Node/JavaScript project**
   - `Glob(pattern='skills/*/SKILL.md')` returns matches → **Skills Repository**
   - None of the above → **Unknown** (answer with karpathy-guidelines only)

2. **Language version detection:**
   - **Go:** `Bash(command='grep "^go " go.mod | cut -d" " -f2')`
   - **Vue/Node:** `Bash(command='node -v')`, check `tsconfig.json` for TypeScript
   - **Skills Repository:** no language version — text-only project

3. **Tooling check:**
   - **Go:** `Bash(command='which go && which golangci-lint')`
   - **Vue/Node:** `Bash(command='which node && (which npm || which pnpm)')`
   - **Skills Repository:** `Bash(command='which git')`

4. **Announce findings with explicit exit statement:**
   ```
   "Phase 0: Environment — [type], [version]
   Tooling: go/node/git available
   → Phase 0.3 + 0.5"
   ```

5. **Auto-transition:** Launch Phase 0.3 and Phase 0.5.

---

## Phase 0.3: Codebase Analysis + Knowledge Layer

<HARD-GATE>
`.claude/context/knowledge.md` missing OR commit SHA ≠ HEAD → MUST run Phase 0.3.
Skip ONLY when knowledge.md exists AND commit matches AND announced with reason.
</HARD-GATE>

**Goal:** Analyze codebase → generate/refresh `.claude/context/knowledge.md` (Knowledge Layer).

**Procedure:**

1. **Freshness check:**
   - `Read('.claude/context/knowledge.md')` → read header commit SHA
   - `Bash(command='git rev-parse HEAD')` → current SHA
   - Match → announce "Knowledge Layer fresh (commit <sha>), skipping analysis."
   - No match or no file → proceed to step 2

2. **Announce:** "**Phase 0.3: Codebase Analysis** — understanding the project before proceeding."

3. **Analyze AND write** (single Agent, analysis + file write):
   - **Go project:** `Agent(description='Analyze Go codebase and write knowledge.md', prompt='Analyze this Go codebase architecture: error handling patterns, DI approach, concurrency model, testing conventions. Map key entities with source paths. Then Write the full analysis to .claude/context/knowledge.md. Header: <!-- ⚠️ Auto-generated | Commit: <sha> | Date: <iso> | Go <version> -->.', subagent_type='general-purpose')`
   - **Vue/Node project:** `Agent(description='Analyze frontend codebase and write knowledge.md', prompt='Analyze this frontend codebase: component tree, routing, state management, testing setup. Map key components with source paths. Then Write the full analysis to .claude/context/knowledge.md. Header: <!-- ⚠️ Auto-generated | Commit: <sha> | Date: <iso> | <type> -->.', subagent_type='general-purpose')`
   - **Skills Repository:** `Agent(description='Analyze skills repository and write knowledge.md', prompt='Analyze this Skills Repository: SKILL.md inventory by category, reference integrity, directory structure. Map key patterns. Then Write the full analysis to .claude/context/knowledge.md. Header: <!-- ⚠️ Auto-generated | Commit: <sha> | Date: <iso> | Skills Repository -->.', subagent_type='general-purpose')`
   - Header MUST include commit SHA + date + project type
   - Full overwrite — no merge

4. **Cross-validation** (lightweight):
   - Sample 3-5 source paths from analysis → `Read()` verify existence
   - For Go: architecture claims vs `Grep` in `go.mod`
   - Log failures but don't block

5. **Announce results:**
   ```
   "Phase 0.3: Codebase Analysis — [project-type], commit <sha>
   Knowledge Layer: generated — N patterns, N entities, N interfaces
   Cross-validation: [pass/fail details]
   → knowledge.md written. → Phase 0.5."
   ```

---

## Phase 0.5: Smart Skill Selection

**Goal:** Select exactly the right skills for this task — no more, no less.

**Procedure:**

1. **Codebase signal matching** (from Phase 0 dependency scan):
   - **Go:** `Read('go.mod')` → scan for samber, grpc, testify, etc. → match against `references/full-skill-routing.md`
   - **Vue:** `Read('package.json')` → scan for vue, pinia, vitest → match against routing table
   - For EVERY match: `Skill(skill='<name>')`

2. **Task signal matching:**
   - Match keywords against `references/full-skill-routing.md`
   - Load each matched skill via `Skill(skill='<name>')`

3. **Baseline** (no Skill calls, internalized):
   - `karpathy-guidelines`: Think before coding, surgical changes, fresh evidence

4. **Memory trigger detection:**
   - Scan `~/.claude/projects/.../memory/` for `→ 加载 skill <name>` pattern
   - Load matched skills via `Skill(skill='<name>')`
   - Skip already-loaded skills

5. **Announce selection with explicit exit:**
   ```
   "Phase 0.5: Skills
   - Codebase signals: N skills loaded
   - Task signals: N skills loaded
   - Total: N skills
   → Phase 1."
   ```

---

## Phase 1: Design First (HARD-GATE)

<HARD-GATE>
Before writing or editing any file, present approach → get user approval.
Simple projects = shorter design, but still present it first.
</HARD-GATE>

**Goal:** Turn ideas into fully formed designs through collaborative dialogue. Explore codebase first, then Grill (one question at a time with recommended answers), exit when all 4 clarity dimensions are clear.

**Source:** Adapted from obra/superpowers brainstorming pattern, Karpathy 5 principles.

**Procedure:**

1. **EXPLORE FIRST** (timebox 60 seconds):
   - Read top-level files matching task keywords.
   - `Bash(command='git log --oneline -5', description='Recent changes context')`
   - If the codebase already answers a question, skip that question — never re-ask what's in the repo.
   - Hard limit: 60 seconds. Move on when the timer expires.

2. **GRILL** (one question at a time):
   - **Mandatory first question:** Confirm scope boundary — "Here's what I think is in/out of scope based on exploration. Is this correct?" Ask nothing else until boundary is pinned.
   - Then proceed through remaining clarity dimensions: intent (why, root cause), constraints (versions, deps, non-negotiables), success criteria (concrete, verifiable, how to prove done).
   - **Each question MUST embed a recommended answer:** "I think X because Y — does that work?" This reduces decision fatigue. Explain reasoning and explicitly invite disagreement to avoid anchoring bias.
   - **Exit condition:** Self-check all 4 clarity dimensions (intent, boundary, constraints, success) before asking the next question. When all 4 hold, announce:
     ```
     "Grill mode complete — all 4 dimensions clear:
      1. Intent: [statement]
      2. Boundary: [statement]
      3. Constraints: [statement]
      4. Success criteria: [statement]
      → Moving to approach design."
     ```
     Then auto-transition to PROPOSE.

3. **PROPOSE** — 2-3 approaches with trade-offs and recommendation.

4. **WRITE SPEC** — `Agent(description='Write design spec', prompt='Write the design spec to .claude/specs/YYYY-MM-DD-<topic>-design.md. Content: [spec_content].', subagent_type='general-purpose')`

5. **SELF-REVIEW** — Check for TBD/TODO, contradictions, ambiguous scope.

6. **SKILL RE-CHECK** (after design approved):
   - Re-scan codebase + task signals against routing table.
   - Diff against Phase 0.5 loaded skills → load missing ones via `Skill(skill='<name>')`.
   - Post-design codebase context may surface additional needed skills.

7. **APPROVAL** — Present spec to user for confirmation.
   - On approval: **Auto-transition to Phase 2.**

---

## Phase 2: Write Plan

**Goal:** Produce a concrete, written implementation plan.

**Procedure:**

1. Announce: "**Phase 2: Write Plan** — writing plan to `.claude/plans/`."

2. Write plan to `.claude/plans/YYYY-MM-DD_HHMMSS-<slug>.md`:
   - **Goal**: What we're building — concise one-liner
   - **Context**: Version, project type, key decisions from Phase 0/1
   - **Approach**: Step-by-step with exact file paths
   - **Files**: All files to create or modify, with expected changes
   - **Verification**: How we'll test each step
   - **Risks**: Known risks, tradeoffs, open questions

3. `Agent(description='Write implementation plan', prompt='Write the implementation plan to .claude/plans/<timestamp>-<slug>.md with Goal, Context, Approach, Files, Verification, Risks sections.', subagent_type='general-purpose')`

4. Auto-transition to Phase 3.

---

## Phase 3: Ralplan Consensus Planning

**Goal:** Produce a reviewed, critic-validated implementation plan before writing code.

**Procedure:**

1. Announce: "**Phase 3: Ralplan Consensus** — reviewing the plan."

2. **OMC prerequisite check:**
   - Try `Skill(skill='ralplan')` with the plan as context
   - If ralplan succeeds → Planner→Architect→Critic consensus loop runs automatically
   - If ralplan unavailable → **Fallback**: Run simplified inline consensus:
     a. Present plan summary + RALPLAN-DR (Principles, Decision Drivers, Options)
     b. `Agent(description='Architect review', prompt='Review for architectural soundness...')`
     c. After Architect completes: `Agent(description='Critic review', prompt='Evaluate quality criteria...')`
     d. Address feedback, re-review until APPROVE or 3 iterations

3. **Output:** Bite-sized task list with file paths, expected changes, verification criteria.

4. Present the plan for user approval before proceeding.

5. Auto-transition to Phase 4.

---

## Phase 4: Implement (Workflow Parallel)

**Goal:** Execute the plan using Claude Code's Workflow tool for precise pipeline orchestration.

**Procedure:**

1. Announce: "**Phase 4: Implement** — executing via Workflow orchestration."

2. **Workflow pre-flight check:**
   - Confirm Workflow tool is available in current session schema
   - If absent → fall back to sequential `Agent()` calls with manual coordination

3. **Build the Workflow script:**
   ```javascript
   export const meta = {
     name: 'phase4-implement',
     description: 'Implement tasks from plan with review-verify pipeline',
     phases: [{ title: 'Implement' }, { title: 'Review' }, { title: 'Verify' }],
   }

   const TASKS = [/* extracted from Phase 3 plan */]

   phase('Implement')
   const results = await pipeline(
     TASKS,
     // Stage 1: Implement
     task => agent(`Implement: ${task.description}. Files: ${task.files.join(', ')}`, {
       label: `impl:${task.id}`,
       schema: { type: 'object', properties: { files: {}, summary: {}, errors: {} } }
     }),
     // Stage 2: Self-review (per-task, no barrier)
     impl => agent(`Review implementation of ${impl.summary}. Check: spec compliance, style, tests.`, {
       label: `review:${impl.files?.[0]}`,
     }),
     // Stage 3: Verify (per-task, no barrier)
     review => agent(`Verify: run build+test for ${review}. Report pass/fail.`, {
       label: `verify:${review}`,
     })
   )

   log(`Implemented ${results.filter(Boolean).length}/${TASKS.length} tasks`)
   ```

4. **Workflow execution pattern:**
   - `pipeline()` over tasks — each task flows through implement→review→verify independently
   - Results that fail verification → re-queued for next iteration
   - Max 3 retries per task

5. **Post-implementation:**
   - `Bash(command='git diff --stat')` → summarize changes
   - Report: tasks completed, files changed, any failures

6. Auto-transition to Phase 5.

---

## Phase 5: Two-Stage Review (ALWAYS RUNS)

**Goal:** Spec compliance review first → code quality review second. NEVER reverse order.

### Stage 1: Spec Compliance Review

1. `Bash(command='git diff --name-only')` → list changed files
2. Re-read the plan file from `.claude/plans/`
3. `Agent(description='Spec compliance review', prompt='Compare implementation against plan. Check: all planned tasks done? extra work not in plan? requirements met?', subagent_type='general-purpose')`
4. **Gate:** ❌ Issues found → fix → re-review. Only proceed when ✅

### Stage 2: Code Quality Review

1. `Agent(description='Code quality review', prompt='Review changed files for: correctness, simplicity, error handling, concurrency safety, style consistency. Flag CRITICAL/HIGH/MEDIUM/LOW.', subagent_type='general-purpose')`
2. **Deep depth:** Add modernization audit for Go projects (go.mod ≥ 1.21)
3. Fix CRITICAL and HIGH before Phase 6. Re-review if substantial.

**Red Flags (NEVER):**
- Start code quality before spec compliance is ✅
- Skip either stage
- Accept "close enough"

---

## Phase 6: Verified Completion (Iron Law)

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

**Goal:** Run ALL verification commands, read ALL output, confirm ALL pass.

**Verification Routing (by project type):**

**Go:**
1. `Bash(command='go mod tidy', description='Clean go.sum')`
2. `Bash(command='go build ./...', description='Build all packages')` — must exit 0
3. `Bash(command='go vet ./...', description='Run go vet')` — no warnings
4. `Bash(command='go test -race -count=1 ./...', description='Run all tests with race detector')` — ALL PASS
5. `Bash(command='go run golang.org/x/vuln/cmd/govulncheck@latest ./...', description='Vulnerability scan')`
6. `Bash(command='golangci-lint run ./...', description='Lint check')` — 0 warnings

**Vue / Node:**
1. `Bash(command='npm ci', description='Clean install')` (or `pnpm install`)
2. `Bash(command='npx tsc --noEmit', description='Type check')` (if TypeScript)
3. `Bash(command='npm test', description='Run tests')` — ALL PASS
4. `Bash(command='npm run lint', description='Lint check')` — 0 warnings

**Skills Repository:**
1. `Bash(command='grep -c "^## Phase" skills/project-workflow/SKILL.md', description='Phase count check')`
2. `Bash(command='head -15 skills/*/SKILL.md | head -30', description='Spot-check YAML frontmatter')`
3. `Bash(command='grep -rn "TODO\|FIXME" skills/', description='Check unresolved issues')`
4. `Bash(command='git diff --check', description='No whitespace errors')`

**On ANY failure:**
- OMC available: `Skill(skill='ralph')` → fix → re-verify loop
- OMC unavailable: Manual fix → re-run verification → repeat until ALL pass

**Completion Declaration:**
```
"Phase 6: Verified
- Build: ✓ (exit 0)
- Test: ✓ (N/N PASS)
- Lint: ✓ (0 warnings)
- Security: ✓ (0 vulnerabilities)"
```

---

## Phase 7: Retrospective & Learning

**Goal:** Three-layer learning: session reflection (7.1), inline self-learning (7.2), cross-session memory cron (7.3).

### 7.1 Session-End Retrospective

`Agent(description='Session retrospective', prompt='Scan this session: errors, user corrections, skill misses, patterns. Extract lessons. Save to memory. Output retrospective report.', run_in_background=true)`

### 7.2 Self-Learning (inline triggers)

| Trigger | Action |
|---------|--------|
| Phase 6 failed >3 times on same issue | Load `diagnose` skill |
| Phase 6 found >5 modernization warnings | Load `golang-modernize` |
| User corrected same pattern ≥2 times | Save to memory as durable preference |

### 7.3 Background Memory Cron

```
CronCreate(
  cron='7 */2 * * *',  // every 2 hours at minute 7
  prompt="Phase 7.3 Memory Cron. Scan recent sessions for patterns. If memory ≥90% full, compress into memory-backup skills. Otherwise extract cross-session conventions.",
  durable=true
)
```

Note: Recurring tasks auto-expire after 7 days — this is expected. The cron will be re-created on next workflow run.

---

## Phase 8: Finish Branch

**Goal:** Structured completion of development work.

1. **Verify Phase 6 results still hold** (no new code since verification)
2. **Detect environment:**
   - `Bash(command='git rev-parse --git-dir')` vs `Bash(command='git rev-parse --git-common-dir')`
3. **Determine base branch:**
   - `Bash(command='git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null')`
4. **Present 4-option menu:**
   - `AskUserQuestion(question="What would you like to do?", options=[Merge locally, Push and create PR, Keep branch as-is, Discard this work])`
5. **Execute choice** (merge/push/keep/discard with appropriate git commands)

---

## Self-Driving Transition Rules

| Phase | Auto-transition to | Condition |
|-------|-------------------|-----------|
| 0 (Environment) | 0.3 + 0.5 | Detection complete |
| 0.5 (Skills) | 1 (Design) | 0.3 analysis complete + skills loaded |
| 1 (Design) | 2 (Plan) | Design approved + spec written |
| 2 (Plan) | 3 (Ralplan) | Plan saved to `.claude/plans/` |
| 3 (Ralplan) | 4 (Implement) | Plan approved |
| 4 (Implement) | 5 (Review) | All tasks done |
| 5 (Review) | 6 (Verify) | Both stages pass (spec ✅ then code ✅) |
| 6 (Verify) | 7 (Retro+Cron) | ALL checks PASS with fresh evidence |
| 7 (Retro+Cron) | 8 (Finish) | 7.1+7.2 dispatched; 7.3 cron runs independently |
| 8 (Finish) | Done | User choice executed |

## Escape Hatches

| Command | Effect |
|---------|--------|
| `quick` / `fast` | Force quick depth (lightweight interview + review) |
| `deep` / `careful` | Force deep depth (full review + modernization audit) |
| `skip design` | Jump to Phase 2 |
| `skip plan` | Jump to Phase 4 |
| `no review` | Skip Phase 5 (DANGEROUS) |
| `I'll test` | Skip Phase 6 verification |
| `skip branch` | Skip Phase 8 |
| `FULL` | All phases with deep depth |

## Anti-Patterns (NEVER)

1. ❌ Skip Phase 0 (environment detection) — leads to wrong tool choices
2. ❌ Skip Phase 1 design presentation — even simple projects need a plan
3. ❌ Skip Phase 5 (two-stage review) for non-trivial changes
4. ❌ Skip Phase 6 (Iron Law verification) — "should work" = lying
5. ❌ Load all possible skills "just in case" — select based on signals
6. ❌ Present plan inline without saving to `.claude/plans/`
7. ❌ Start code quality review before spec compliance is ✅
8. ❌ Use old Go version when go.mod specifies newer
9. ❌ Claim completion without running verification commands THIS turn

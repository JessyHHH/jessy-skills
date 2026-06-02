---
name: project-workflow-claude
description: "Use when starting any development task — auto-detects project type, loads matching skills, drives 11-phase pipeline from design through verified completion. Hard Gates + Iron Law."
version: "v2.1"
author: "jessyhuang"
metadata:
  standalone: true
---

# Project Workflow Claude v2.1 — Self-Driving Pipeline with Hard Gates

**Core design:** Zero pre-loaded skills (except `karpathy-guidelines`). Everything is context-detected: Go version, project type, codebase patterns, task signals. **Workflow-script-driven:** Phase 4-6 use deterministic JS scripts (`~/.claude/workflows/project-workflow-claude/phase4-implement.js`, `phase5-review.js`, `phase6-verify.js`) executed via the Workflow tool. Scripts support caching, resume, and structured output. **Layered skill routing:** Shared domain skills (Go/Vue/Engineering) + Claude Code platform overlay.

**Self-driving:** Announce phases → execute → auto-transition. Never wait for user to say "next".

**Platform:** Claude Code v2.1+. Standalone — no external dependencies. Uses Claude Code native tools — `Workflow`, `Agent`, `Skill`, `Glob`, `Grep`, `Bash`, `AskUserQuestion`, `CronCreate`.

**Workflow Script Resolution:** The 4 Workflow scripts are installed to `~/.claude/workflows/` by `install.sh`. The Workflow tool's `name` parameter auto-discovers scripts from `~/.claude/workflows/` and `.claude/workflows/` — no path resolution needed. Always use `Workflow(name='phase<N>-<name>')` form.

---

## Delegation Rules (MANDATORY)

The master agent is a SUPERVISOR, not an implementer. ALL file modifications MUST be delegated to subagents.

| Operation | Who | Tool |
|-----------|-----|------|
| Read, search, plan, design | Master agent | Read, Glob, Grep, AskUserQuestion |
| Skill loading | Master agent | Skill |
| Shell commands (Bash) | Master agent | Bash |
| CRITICAL: File writing | Subagent ONLY | Agent(general-purpose) |
| Multi-file implementation | Subagent pipeline | Agent(general-purpose, model='sonnet' default) |
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
5. **Verify Before Asserting** — Use priority chain: Context7 MCP (docs) → Firecrawl MCP (search) → WebFetch → WebSearch. Don't guess.

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

4. **MCP availability detection:**
   - Check available tool names in current session for "context7" (case-insensitive) → Context7 MCP
   - Check available tool names for "firecrawl" (case-insensitive) → Firecrawl MCP
   - If neither available: document queries fallback to WebFetch, search fallback to WebSearch
   - If missing but recommended: suggest consulting `references/setup.md` for installation

5. **Announce findings with explicit exit statement:**
   ```
   "Phase 0: Environment — [type], [version]
   Tooling: go/node/git available
   MCP: context7 [available/not available], firecrawl [available/not available]
   → Phase 0.3 + 0.5"
   ```

6. **Auto-transition:** Launch Phase 0.3 and Phase 0.5.

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
   - `Read('CLAUDE.md')` → read header commit SHA (if file exists)
   - `Bash(command='git rev-parse HEAD')` → current SHA
   - Both files independently compared against HEAD
   - Stale knowledge.md → regenerate knowledge.md
   - Stale CLAUDE.md → update CLAUDE.md AUTO blocks
   - Match → announce "Knowledge Layer fresh (commit <sha>), skipping analysis."
   - No match or no file → proceed to step 2

2. **Announce:** "**Phase 0.3: Codebase Analysis** — understanding the project before proceeding."

3. **Analyze AND write** (single Agent, analysis + file write):
   - **Go project:** `Agent(description='Analyze Go codebase and write knowledge.md', prompt='Analyze this Go codebase architecture: error handling patterns, DI approach, concurrency model, testing conventions. Map key entities with source paths. Then Write the full analysis to .claude/context/knowledge.md. Header: <!-- ⚠️ Auto-generated | Commit: <sha> | Date: <iso> | Go <version> -->.', subagent_type='general-purpose')`
   - **Vue/Node project:** `Agent(description='Analyze frontend codebase and write knowledge.md', prompt='Analyze this frontend codebase: component tree, routing, state management, testing setup. Map key components with source paths. Then Write the full analysis to .claude/context/knowledge.md. Header: <!-- ⚠️ Auto-generated | Commit: <sha> | Date: <iso> | <type> -->.', subagent_type='general-purpose')`
   - **Skills Repository:** `Agent(description='Analyze skills repository and write knowledge.md + CLAUDE.md', prompt='
     1. Analyze this Skills Repository: SKILL.md inventory by category, reference integrity,
        directory structure. Map key patterns.
     2. Write full analysis to .claude/context/knowledge.md.
        Header: <!-- ⚠️ Auto-generated | Commit: <sha> | Date: <iso> | Skills Repository -->
     3. Check CLAUDE.md:
        a. If CLAUDE.md does NOT exist:
           Write full skeleton:
           Line 1: <!-- ⚠️ Auto-generated | Commit: <sha> | Date: <iso> | Skills Repository -->
           Then template:

           # <project-name> — Claude Code Configuration

           ## Project
           <!-- AUTO_START: Project -->
           <project type and version from Phase 0>
           Core workflow: `project-workflow-claude` + `karpathy-guidelines`
           <!-- AUTO_END: Project -->

           ## Essential Commands
           <!-- AUTO_START: Commands -->
           <build/test/lint commands from Phase 0>
           <!-- AUTO_END: Commands -->

           ## Conventions
           (Human-editable — machine never touches this section)
           <inferred from codebase, 2-3 items>

           ## Project Knowledge
           Architecture analysis: [.claude/context/knowledge.md](.claude/context/knowledge.md)
           Full workflow: load `project-workflow-claude` skill

        b. If CLAUDE.md exists:
           i. Read it. Check for AUTO_START/AUTO_END markers.
           ii. If zero AUTO markers present (legacy file):
               Wrap existing project summary + core workflow line under ## Project
               in AUTO_START:Project/AUTO_END:Project.
               Wrap existing ## Essential Commands content in
               AUTO_START:Commands/AUTO_END:Commands.
               Add SHA header as line 1.
               Do NOT touch Conventions or Project Knowledge content.
           iii. If AUTO markers present and well-formed:
               Update content between AUTO_START/AUTO_END pairs (Project + Commands).
               Update SHA header date/commit.
               Preserve ALL content outside AUTO markers.
           iv. If AUTO markers present but malformed:
               Emit warning: "CLAUDE.md has malformed AUTO markers. Please fix manually.
               Skipping CLAUDE.md update." Do NOT touch the file.
     ', subagent_type='general-purpose')`
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
   CLAUDE.md: [fresh | generated | updated (N blocks) | skipped (malformed markers — fix manually) | upgraded (first-touch AUTO markers added)]
   Cross-validation: [pass/fail details]
   → knowledge.md + CLAUDE.md ready. → Phase 0.5."
   ```

---

## Phase 0.5: Smart Skill Selection

**Goal:** Select exactly the right skills for this task — no more, no less.

**Procedure:**

0. **Load platform overlay:** `Read('references/claude-routing.md')` → load Claude Code-specific action mappings.
   **Conflict resolution:** Overlay takes precedence over base layer. Deduplicate by skill name (skip already-loaded skills). If both layers match, log collision and use overlay.

1. **Codebase signal matching** (from Phase 0 dependency scan):
   - **Go:** `Read('go.mod')` → scan for samber, grpc, testify, etc. → match against `../project-workflow/references/full-skill-routing.md` (base layer, shared) and `references/claude-routing.md` (overlay)
   - **Vue:** `Read('package.json')` → scan for vue, pinia, vitest → match against routing tables
   - For EVERY match: `Skill(skill='<name>')`

   1.5. **MCP-aware routing:** If Context7 available → prefer for docs/library queries. If Firecrawl available → prefer for web searches.

   **Iron Law loading:** If task involves code changes or verification → `Read('references/iron-law.md')` to enforce verification discipline.

2. **Task signal matching:**
   - Match keywords against `../project-workflow/references/full-skill-routing.md` and `references/claude-routing.md`
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
   - Overlay: claude-routing.md loaded
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

**Source:** Adapted from brainstorming-ideas pattern, Karpathy 5 principles.

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

5. **SELF-REVIEW** (after writing spec, BEFORE user review — fix all issues inline):
   a. **PLACEHOLDER SCAN** — "TBD", "TODO", incomplete sections, vague requirements
   b. **INTERNAL CONSISTENCY** — Contradictions between sections? Inconsistent assumptions?
   c. **SCOPE CHECK** — Focused enough for a single implementation plan? Needs decomposition into sub-projects?
   d. **AMBIGUITY CHECK** — Requirements with two interpretations → pick one, make it explicit
   → Fix ALL issues before presenting to user. Never show an unreviewed spec.

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
   - **Tasks**: JSON task block (```json:tasks) with id, prompt, files, complexity, mutatesFiles — for Phase 4 Workflow consumption

3. `Agent(description='Write implementation plan', prompt='Write the implementation plan to .claude/plans/<timestamp>-<slug>.md with Goal, Context, Approach, Files, Verification, Risks sections. Include a ```json:tasks fenced code block at the end with an array of task objects: {id, prompt, files, complexity, mutatesFiles}. Each prompt must be a self-contained implementation instruction suitable for a subagent starting with blank context.', subagent_type='general-purpose')`

4. Auto-transition to Phase 3.

---

## Phase 3: Consensus Review

**Goal:** Produce a reviewed, critic-validated implementation plan before writing code.

**Procedure:**

1. Announce: "**Phase 3: Consensus Review** — reviewing the plan."

2. **Judge Panel Review:**
   ```
   Workflow(
     name='phase3-consensus',
     args={planContent: '<full plan text>'}
   )
   ```
   Script reviews from 3 angles in parallel (architecture, risk, feasibility), scores 1-10 each, synthesizes one verdict.

3. **Act on verdict:**
   - If APPROVE → proceed to step 5 (output task list)
   - If ITERATE → address findings → re-run Workflow (max 3 iterations)
   - If REJECT → present to user with reasons. Do NOT proceed.

5. **Output:** Bite-sized task list with file paths, expected changes, verification criteria.

6. Present the plan for user approval before proceeding.

7. Auto-transition to Phase 4.

---

## Phase 4: Implement (Workflow Pipeline)

**Goal:** Execute all implementation tasks in parallel using a deterministic Workflow script. Phase 5 handles review, Phase 6 handles full verification.

**Procedure:**

1. **ANNOUNCE:** "**Phase 4: Implement** — Workflow(pipeline) via phase4-implement.js."

2. **LOAD TASKS:**
   - Read the Phase 3 plan from `.claude/plans/`
   - Extract the `json:tasks` fenced code block → parse JSON → get tasks array
   - Each task: `{id, prompt, files, complexity, mutatesFiles}`
   - `prompt` must be a self-contained implementation instruction (subagent starts with blank context)

3. **EXECUTE:**
   ```
   Workflow(
     name='phase4-implement',
     args={tasks: [...]}
   )
   ```

   The script uses `pipeline()` (streaming, no barrier):
   - Stage 1 (Implement): `agent(task.prompt, {model, isolation})` per task
     - complexity='simple' → haiku, 'medium' → sonnet, 'complex' → opus
     - mutatesFiles=true → isolation='worktree' (avoids file conflicts)
   - Stage 2 (Quick Verify): `agent(verify, {phase: 'Quick Verify', schema})` per task
     - Each task verified immediately after implementation (streaming — no waiting for other tasks)
     - Validates: build passes + affected tests pass

   The script includes a Self-Review stage: each implementer reports DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED. The script returns `selfReviewStatus` — pass this to Phase 5 as `args.selfReviewStatuses`. If budget.total is set, tasks are prioritized by complexity.

4. **REPORT** — auto-transition to Phase 5:
   ```
   "Phase 4: Implemented
   - Tasks: N/N completed, M passed, B failed
   - Files: <count> changed
   → Phase 5."
   ```
   If failures → collect failed task IDs for Phase 5 review.

5. **ERROR RECOVERY:** If Workflow script throws → Read error from transcript → Agent fix script bug → re-run Workflow.

6. **Auto-transition** to Phase 5.

---

## Phase 5: Two-Stage Review (ALWAYS RUNS)

**Goal:** Spec compliance review first → code quality review second. NEVER reverse order. Uses deterministic Workflow script for parallel code quality audit.

**Procedure:**

1. **ANNOUNCE:** "**Phase 5: Two-Stage Review** — per-task pipeline via phase5-review.js."

2. **PREPARE:**
   - `Bash(command='git diff --name-only')` → changedFiles
   - Re-read plan from `.claude/plans/` → planPath
   - Collect `selfReviewStatuses` from Phase 4 output

3. **EXECUTE:**
   ```
   Workflow(
     name='phase5-review',
     args={planPath, changedFiles, tasks: [...], selfReviewStatuses: [...]}
   )
   ```
   The script uses per-task pipeline review:
   - **Spec Compliance** (gated per task): Each task checked against plan. Self-review statuses (DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED) surfaced in review context.
   - **Code Quality** (only if spec passes): Parallel correctness/safety/simplicity per task
   - **Adversarial Verification**: 3 skeptics vote on each CRITICAL finding (≥2/3 majority to confirm)
   - **Final Review**: Overall cross-task consistency after all tasks pass individual reviews
   - Task A in code quality while Task B in spec review — zero barrier streaming

4. **FIX-AND-RETRY:**
   - Read output → `{criticalCount, highCount, findings, specFailed, finalVerdict}`
   - If `criticalCount > 0`: Agent fixes CRITICAL issues → re-run Workflow. Max 3 iterations.
   - If `specFailed.length > 0`: Address spec gaps → fix implementation or update plan → re-run.
   - Report to user on 3rd failure.

5. **REPORT** → auto-transition to Phase 6:
   ```
   "Phase 5: Reviewed
   - Spec Compliance: [✓/✗]
   - Code Quality: N findings (M CRITICAL, H HIGH)
   → Phase 6."
   ```

**Red Flags (NEVER):**
- Start code quality before spec compliance is ✅
- Skip either stage
- Accept "close enough"

---

## Phase 6: Verified Completion (Iron Law)

> **Iron Law:** The complete Iron Law (Gate Function, Red Flags, Rationalization Prevention, TDD Verification, Agent Delegation Verification, Evidence Standard) is in `references/iron-law.md`. Load via `Read('references/iron-law.md')` when verification enforcement is needed.

### Verification Execution (Workflow Script + Master Agent)

**Goal:** Run ALL verification commands, read ALL output, confirm ALL pass. Fix loop via Workflow script.

**Procedure:**

1. **ANNOUNCE:** "**Phase 6: Verify** — Iron Law enforcement via phase6-verify.js."

2. **RUN CHECKS** (Master Agent):
   Execute ALL commands for the detected project type. Collect results as `[{name, command, exitCode, stdout, stderr}]`.

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
   1. `Bash(command='grep -c "^## Phase" skills/project-workflow-claude/SKILL.md', description='Phase count check')`
   2. `Bash(command='head -15 skills/*/SKILL.md | head -30', description='Spot-check YAML frontmatter')`
   3. `Bash(command='grep -rn "TODO\|FIXME" skills/', description='Check unresolved issues')`
   4. `Bash(command='git diff --check', description='No whitespace errors')`
   5. Reference file existence: `for ref in $(grep -oP 'references/[a-z0-9-]+\.md' skills/project-workflow-claude/SKILL.md); do test -f "skills/project-workflow-claude/$ref" && echo "✓ $ref" || echo "✗ MISSING: $ref"; done`

3. **ANALYZE + FIX** (Workflow Script):
   ```
   Workflow(
     name='phase6-verify',
     args={projectType: '<go|vue|node|skills-repo>', checkResults: [...], dryRounds: <current>}
   )
   ```

   **LOOP UNTIL DRY:** The script returns `{allPassed, dryRounds, shouldContinue}`.
   - `shouldContinue=false, allPassed=true` → DONE (Iron Law satisfied, 2 consecutive dry rounds)
   - `shouldContinue=true` → Master re-runs ALL Bash checks → re-invoke script with updated `checkResults` and current `dryRounds` value
   - Safety cap: 10 total invocations. Report to user if cap reached.

**Note:** Project type tokens passed to Workflow are normalized: `go`, `vue`, `node`, `skills-repo`.

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

**Goal:** Three-layer learning: session reflection (7.1), inline self-learning (7.2), cross-session memory cron with auto-compression (7.3).

### 7.1 Session-End Retrospective

`Agent(description='Session retrospective', prompt='Scan this session: errors, user corrections, skill misses, patterns. Extract lessons. Save to memory. Output retrospective report.', run_in_background=true)`

### 7.2 Self-Learning (inline triggers)

| Trigger | Action |
|---------|--------|
| Phase 6 failed >3 times on same issue | Load `diagnose` skill (if available) |
| Phase 5 found >5 CRITICAL/HIGH findings | Re-examine Phase 1 design assumptions |
| User corrected same pattern ≥2 times | Save to memory as durable preference |
| Plan missed a relevant skill | Update claude-routing.md if pattern repeats |

### 7.3 Background Memory Cron

**Goal:** Persistent cron job (every 2 hours) for cross-session pattern extraction. When memory ≥90% full, auto-compress into topic-based skills.

**Cron Setup (idempotent):**
```
1. CronList → check for existing 'phase7-memory-cron' job
2. IF found → skip creation (already running)
3. IF not found:
   CronCreate(
     cron='7 */2 * * *',
     prompt="Phase 7.3 Memory Cron. Run the COMPRESS_OR_EXTRACT algorithm below. Scan project memory files for patterns. If memory is near capacity, compress into skills. Otherwise extract cross-session conventions.",
     durable=true
   )
```
Note: Recurring tasks auto-expire after 7 days. Re-created on next workflow run only if not already present.

#### COMPRESS_OR_EXTRACT Algorithm

```
1. Scan memory files: Bash(command='ls -t ~/.claude/projects/<project>/memory/*.md 2>/dev/null')
2. Check capacity: Bash(command='wc -c ~/.claude/projects/<project>/memory/*.md | tail -1')
   - Threshold: 10,000 chars total (~90% capacity)
3. IF total chars ≥ 10,000:
     RUN COMPRESSION CYCLE
   ELSE:
     RUN CROSS-SESSION EXTRACTION
```

#### COMPRESSION CYCLE (memory ≥ 90%)

```
1. Read ALL memory files in ~/.claude/projects/<project>/memory/
2. Classify by topic using Agent:
   - Group related entries (e.g., all Go conventions, all project-specific patterns)
   - Each group becomes a candidate skill
3. FOR EACH topic group:
   a. Summarize into 3-5 concise, impactful rules
   b. Name: memory-<topic-slug> (e.g., memory-golang, memory-project-x)
   c. Agent writes skill: Write ~/.claude/skills/memory-<topic>/SKILL.md
      - Frontmatter: name, description, version
      - Content: Key Rules section with 3-5 rules
   d. If skill already exists:
      - Agent reads existing → appends new rules without duplicating
4. REPLACE memory entries:
   - Remove detailed entries that were classified into skills
   - Write compact trigger entries: "<topic>: 加载 skill memory-<topic-slug>"
   - Trigger format MUST be parseable by Phase 0.5
5. Verify: memory total chars dropped by ≥30% from pre-compression level
6. If still ≥10,000 chars after first pass → run second pass with more aggressive summarization
```

#### CROSS-SESSION EXTRACTION (memory < 90%)

```
1. Scan memory files for recurring patterns (same topic appearing across files)
2. IF new durable convention found → Write new memory file
3. IF existing convention contradicted → Edit to update
4. IF stale convention (not referenced in last 10 sessions) → Remove memory file
```

#### Trigger Format Specification

Compressed memory triggers follow this format (machine-parseable by Phase 0.5):

```
<topic>: 加载 skill <skill-name>
```

Example:
```
golang: 加载 skill memory-golang
project-x: 加载 skill memory-project-x
```

#### Generated Skill Format

```yaml
---
name: memory-<topic-slug>
description: "Compressed memory backup — <topic> conventions and lessons. Auto-generated by Phase 7.3."
version: "1.0"
---
# Memory Backup: <Topic>
Auto-generated from compressed agent memory.
## Key Rules
1. <rule 1>
2. <rule 2>
3. <rule 3>
```

---

## Phase 8: Finish Branch

**Goal:** Structured completion of development work. **Optional — user can skip with 'skip branch'.**

1. **Verify Phase 6 results still hold** (no new code since verification)
2. **Detect environment:**
   - `Bash(command='git rev-parse --git-dir')` vs `Bash(command='git rev-parse --git-common-dir')`
3. **Determine base branch:**
   - `Bash(command='git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null')`
4. **Present 4-option menu:**
   - `AskUserQuestion(question="What would you like to do?", options=[Merge locally, Push and create PR, Keep branch as-is, Discard this work])`
5. **Execute choice** (merge/push/keep/discard with appropriate git commands)

### Quick Reference

| Choice | Command |
|--------|---------|
| Merge locally | `git checkout main && git merge <branch>` |
| Push + PR | `git push -u origin <branch>` → create PR via gh |
| Keep as-is | No action |
| Discard | `git checkout main && git branch -d <branch>` (safe: refuses if unmerged) |

### Red Flags (NEVER)
- ❌ Merge before Phase 6 verification
- ❌ Push with failing tests
- ❌ Discard without confirming (data loss)

---

> **Iron Law:** The canonical Iron Law is in `references/iron-law.md`. Load via `Read('references/iron-law.md')` for the complete verification discipline including Gate Function, Red Flags, Rationalization Prevention, TDD Red-Green, and Agent Delegation Verification.

---

## Self-Driving Transition Rules

| Phase | Auto-transition to | Condition |
|-------|-------------------|-----------|
| 0 (Environment) | 0.3 + 0.5 | Detection complete |
| 0.5 (Skills) | 1 (Design) | 0.3 analysis complete + skills loaded |
| 1 (Design) | 2 (Plan) | Design approved + spec written |
| 2 (Plan) | 3 (Consensus) | Plan saved + json:tasks block present |
| 3 (Consensus) | 4 (Implement) | Consensus approved by Judge Panel |
| 4 (Implement) | 5 (Review) | All tasks done |
| 5 (Review) | 6 (Verify) | Both review stages pass (spec per-task ✅ then code per-task ✅ + Final Review ✅) |
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
| `skip workflow` | Fall back to manual Agent parallelism (skip Workflow scripts for Phase 4-6) |
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
10. ❌ Skip Workflow smoke test — leads to script failures
11. ❌ Use parallel() when pipeline() works — pipeline is more efficient
12. ❌ Pass incomplete prompt to Phase 4 task — subagent starts with blank context

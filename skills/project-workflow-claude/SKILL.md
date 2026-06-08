---
name: project-workflow-claude
description: "Use when starting any development task — auto-detects project type, loads matching skills, drives 11-phase pipeline from design through verified completion. Hard Gates + Iron Law."
version: "v2.3"
author: "jessyhuang"
metadata:
  standalone: true
triggers:
  - "start task"
  - "implement"
  - "build"
  - "develop"
  - "add feature"
  - "fix bug"
  - "refactor"
  - "code change"
  - "write code"
---

# Project Workflow Claude v2.3 — Self-Driving Pipeline with Hard Gates

**Core design:** Zero pre-loaded skills (except `karpathy-guidelines`). Everything is context-detected: Go version, project type, codebase patterns, task signals. **Workflow-script-driven:** Phase 4-6 use deterministic JS scripts (`phase4-implement.js`, `phase5-review.js`, `phase6-verify.js`) installed in `~/.claude/workflows/` — executed via the Workflow tool. Scripts support caching, resume, and structured output. **Layered skill routing:** Shared domain skills (Go/Vue/Engineering) + Claude Code platform overlay.

**Self-driving:** Announce phases → execute → auto-transition. Never wait for user to say "next".

**Platform:** Claude Code v2.3+. Standalone — no external dependencies. Uses Claude Code native tools — `Workflow`, `Agent`, `Skill`, `Glob`, `Grep`, `Bash`, `AskUserQuestion`, `CronCreate`.

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

**Goal:** Detect project type, language version, dependency patterns, and available tooling. Capture task intake snapshot.

**Procedure:**

> **Glob fallback:** If the `Glob` tool is not available in your environment (some Claude Code versions/web app), fall back to `Bash(find ...)` commands. Each Glob call below includes a Bash alternative.

1. **Project type detection** (check in order, first match wins):
   - `Glob(pattern='**/go.mod')` returns matches → **Go project** _(fallback: `Bash(command='find . -name "go.mod" -type f 2>/dev/null | head -1')`)_
   - `Glob(pattern='**/package.json')` returns matches → check for Vue/React: _(fallback: `Bash(command='find . -name "package.json" -type f 2>/dev/null | head -1')`)_
     - `Grep(pattern='"vue"', path='package.json')` → **Vue project**
     - `Grep(pattern='"react"', path='package.json')` → **React project**
     - Otherwise → **Node/JavaScript project**
   - `Glob(pattern='skills/*/SKILL.md')` returns matches → **Skills Repository** _(fallback: `Bash(command='ls skills/*/SKILL.md 2>/dev/null | head -1')`)_
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

5. **Task Intake Snapshot:** Capture a structured snapshot of what was requested, what is in/out of scope, and the evidence supporting these determinations. This snapshot provides traceability from the original request through implementation and verification.

   ```json
   {
     "requestSummary": "",
     "repoRoot": "",
     "approvedInScope": [],
     "approvedOutOfScope": [],
     "sourceEvidence": [],
     "constraints": []
   }
   ```

   - `requestSummary`: Concise restatement of the user's request as understood.
   - `repoRoot`: Absolute path to the repository root.
   - `approvedInScope`: Explicitly included deliverables and changes.
   - `approvedOutOfScope`: Explicitly excluded items (prevents scope creep).
   - `sourceEvidence`: References to messages, files, or decisions that support the intake determinations.
   - `constraints`: Known non-negotiables (language version, dependencies, platform requirements).

6. **Announce findings with explicit exit statement:**
   ```
   "Phase 0: Environment — [type], [version]
   Tooling: go/node/git available
   MCP: context7 [available/not available], firecrawl [available/not available]
   → Phase 0.3 + 0.5"
   ```

7. **Auto-transition:** Launch Phase 0.3 and Phase 0.5.

---

## Phase 0.3: Codebase Analysis + Knowledge Layer

<HARD-GATE>
`.claude/context/knowledge.md` missing OR commit SHA ≠ HEAD → MUST run Phase 0.3.
Skip ONLY when knowledge.md exists AND commit matches AND announced with reason.
</HARD-GATE>

**Goal:** Establish context artifacts — root `CONTEXT.md` (durable), optional scoped subdirectory `CONTEXT.md` files, and generated `.claude/context/knowledge.md` (analysis cache).

### Context Artifact Model

Three context artifacts serve different roles:

| Artifact | Role | Managed By | Update Model |
|----------|------|------------|-------------|
| Root `CONTEXT.md` | Durable repository context contract | Humans + machines | Selective refresh (respects `[confirmed]` tags) |
| Scoped subdirectory `CONTEXT.md` | Scope-specific specialization | Humans + machines | Overrides root by proximity |
| `.claude/context/knowledge.md` | Generated analysis cache | Machines only | Full overwrite on every run |

The canonical format specification for `CONTEXT.md` is in `skills/project-workflow-claude/references/context-md-spec.md`. This spec defines the two-layer marker structure (`KNOWLEDGE_START`/`KNOWLEDGE_END`, `INSTRUCTION_START`/`INSTRUCTION_END`), evidence tags (`[confirmed]`, `[auto]`), required fields, and update rules.

**Procedure:**

1. **Freshness check:**
   - `Read('.claude/context/knowledge.md')` → read header commit SHA
   - `Read('CLAUDE.md')` → read header commit SHA (if file exists)
   - `Read('CONTEXT.md')` → read header commit SHA (if file exists)
   - `Bash(command='git rev-parse HEAD')` → current SHA
   - Each artifact independently compared against HEAD
   - Stale knowledge.md → regenerate knowledge.md
   - Stale CONTEXT.md → refresh auto sections, preserve confirmed content
   - Stale CLAUDE.md → update CLAUDE.md AUTO blocks
   - Match → announce "Context artifacts fresh (commit <sha>), skipping analysis."
   - No match or no file → proceed to step 2

2. **Announce:** "**Phase 0.3: Codebase Analysis** — establishing context artifacts."

3. **Analyze AND write** (single Agent, analysis + file write):

   - **Go project:** `Agent(description='Analyze Go codebase and create context artifacts', prompt='1. Analyze this Go codebase architecture: error handling patterns, DI approach, concurrency model, testing conventions. Map key entities with source paths. 2. Write CONTEXT.md (root) following the format spec in skills/project-workflow-claude/references/context-md-spec.md with KNOWLEDGE_START/KNOWLEDGE_END and INSTRUCTION_START/INSTRUCTION_END markers. 3. Write .claude/context/knowledge.md (full overwrite). Header: <!-- ⚠️ Auto-generated | Commit: <sha> | Date: <iso> | Go <version> -->.', subagent_type='general-purpose')`

   - **Vue/Node project:** `Agent(description='Analyze frontend codebase and create context artifacts', prompt='1. Analyze this frontend codebase: component tree, routing, state management, testing setup. Map key components with source paths. 2. Write CONTEXT.md (root) following the format spec in skills/project-workflow-claude/references/context-md-spec.md with KNOWLEDGE_START/KNOWLEDGE_END and INSTRUCTION_START/INSTRUCTION_END markers. 3. Write .claude/context/knowledge.md (full overwrite). Header: <!-- ⚠️ Auto-generated | Commit: <sha> | Date: <iso> | <type> -->.', subagent_type='general-purpose')`

   - **Skills Repository:** `Agent(description='Analyze skills repository and create context artifacts + CLAUDE.md', prompt='
     1. Analyze this Skills Repository: SKILL.md inventory by category, reference integrity,
        directory structure. Map key patterns.
     2. Write CONTEXT.md (root) following the format spec in
        skills/project-workflow-claude/references/context-md-spec.md
        with KNOWLEDGE_START/KNOWLEDGE_END and INSTRUCTION_START/INSTRUCTION_END markers.
     3. Write .claude/context/knowledge.md (full overwrite).
        Header: <!-- ⚠️ Auto-generated | Commit: <sha> | Date: <iso> | Skills Repository -->
     4. Check CLAUDE.md:
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
   - CONTEXT.md: selective refresh (preserves `[confirmed]` tags)
   - knowledge.md: full overwrite — no merge

4. **Cross-validation** (lightweight):
   - Sample 3-5 source paths from analysis → `Read()` verify existence
   - For Go: architecture claims vs `Grep` in `go.mod`
   - Log failures but don't block

5. **Output contextSummary:** After context artifacts are written, produce a structured summary:

   ```json
   {
     "rootContextPath": "CONTEXT.md",
     "rootContextStatus": "present|missing|created",
     "nearestContextPaths": [],
     "knowledgePath": ".claude/context/knowledge.md",
     "knowledgeStatus": "fresh|stale|generated",
     "contextWarnings": [],
     "confirmedFacts": [],
     "autoFacts": []
   }
   ```

   - `rootContextStatus`: `present` (up-to-date), `missing` (does not exist), `created` (newly generated)
   - `nearestContextPaths`: list of scoped subdirectory CONTEXT.md files found (sorted by depth, nearest first)
   - `knowledgeStatus`: `fresh` (commit matches), `stale` (commit mismatch), `generated` (newly written)
   - `contextWarnings`: contradiction warnings, malformed marker warnings, stale evidence
   - `confirmedFacts`: key `[confirmed]` facts loaded from CONTEXT.md
   - `autoFacts`: key `[auto]` facts loaded from CONTEXT.md

6. **Announce results:**
   ```
   "Phase 0.3: Codebase Analysis — [project-type], commit <sha>
   CONTEXT.md: [present|missing|created]
   Knowledge Layer: [fresh|stale|generated] — N patterns, N entities, N interfaces
   CLAUDE.md: [fresh | generated | updated (N blocks) | skipped (malformed markers — fix manually) | upgraded (first-touch AUTO markers added)]
   Cross-validation: [pass/fail details]
   → CONTEXT.md + knowledge.md + CLAUDE.md ready. → Phase 0.5."
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

**Goal:** Turn ideas into fully formed designs through collaborative dialogue. Explore codebase first, then Grill — one question at a time with recommended answers, with variable depth determined by task complexity.

**Source:** Adapted from brainstorming-ideas pattern, Karpathy 5 principles.

**Procedure:**

1. **EXPLORE FIRST** (timebox 60 seconds):
   - Read top-level files matching task keywords.
   - `Bash(command='git log --oneline -5', description='Recent changes context')`
   - If the codebase already answers a question, skip that question — never re-ask what's in the repo.
   - Hard limit: 60 seconds. Move on when the timer expires.

1.5. **REQUIREMENT ECHO:**

   After exploration, print a structured restatement of every requirement extracted from:
   - User's original message
   - Task Intake Snapshot (Phase 0)
   - Files read during EXPLORE
   - Any relevant CONTEXT.md or knowledge.md facts

   Format:
   "Requirements extracted:
    1. [requirement] — source: [user message / intake snapshot / file X]
    2. [requirement] — source: [user message / intake snapshot / file X]
    ...

   Complete and correct? (yes/no)"

   Ask the user: "Complete and correct?" before proceeding to the first Grill question.
   If the user says no, update the requirements list.
   If the user says yes, the echoed requirements become the authoritative scope baseline for the rest of Phase 1.

2. **GRILL** (one question at a time with recommended answers):

   The Grill is a variable-depth requirements crystallization process. Its depth scales with task complexity: it may ask 0 questions for a well-specified, tight-scope task, or many questions for a complex, ambiguous one.

   **Mandatory first question:** Confirm scope boundary — "Here's what I think is in/out of scope based on exploration. Is this correct?" Ask nothing else until boundary is pinned.

   **Ambiguity Register** — maintain a live list of unresolved questions that could change files, behavior, verification, or risk. Each entry includes:
   - **Question**: the unresolved item
   - **Status**: `open` | `answered` | `assumed` | `deferred-out-of-scope`
   - **Impact**: what would change based on the answer (files, behavior, verification, risk)
   - **Recommended answer**: "I think X because Y — does that work?"
   - **Decision**: the final resolved answer

   **Assumption Ledger** — maintain a list of allowed assumptions. Each entry includes:
   - **Assumption**: what is being assumed
   - **Evidence**: what supports this assumption
   - **Confidence**: High | Medium | Low
   - **Correction/rollback path**: what to do if the assumption proves wrong

   **Variable-depth exit criteria:** The grill exits when the mandatory Hard Grill Checklist is satisfied:

   **HARD GRILL CHECKLIST (mandatory printed output before exit):**

   The master agent MUST print this checklist with PASS/FAIL for each item.
   If any item is FAIL, the Grill is NOT done. Re-open Ambiguity Register.

   1. [ ] Ambiguity Register printed (minimum 3 items, or explain why <3)
   2. [ ] Assumption Ledger printed (minimum 2 entries, or explain why <2)
   3. [ ] Every "open" ambiguity addressed (asked user OR moved to "assumed" with ledger entry)
   4. [ ] Success criteria are observable (specific commands + expected output)
   5. [ ] Constraints documented (version, dep, compatibility)
   6. [ ] Self-grade: "Could someone implement from this spec without asking basic questions?"
          If no → grill NOT done. Re-open and probe.

   ALL items MUST pass before proceeding to PROPOSE.

   **GRILL EVIDENCE PERSISTENCE:**
   After ALL checklist items pass and before writing the spec, write a structured JSON file
   to `.claude/state/grill-evidence.json` (delegate to subagent):

   ```json
   {
     "timestamp": "<ISO 8601>",
     "session": "<session-id>",
     "ambiguityRegister": [
       {"id": "A1", "question": "...", "status": "answered|assumed|deferred-out-of-scope",
        "impact": "...", "recommendedAnswer": "...", "decision": "..."}
     ],
     "assumptionLedger": [
       {"id": "S1", "assumption": "...", "evidence": "...",
        "confidence": "high|medium|low", "correctionPath": "..."}
     ],
     "checklistResults": {
       "ambiguityRegisterPrinted": true, "assumptionLedgerPrinted": true,
       "openAmbiguitiesAddressed": true, "successCriteriaObservable": true,
       "constraintsDocumented": true, "selfGrade": "PASS: spec is implementable without basic questions"
     },
     "requirementEcho": ["req1", "req2"],
     "scopeStatement": "...",
     "successCriteria": ["cmd: <command> exits 0", "semantic: <behavior>"]
   }
   ```

   Phase 4.6 reads this file to cross-reference evidence.
   Phase 6 reads this file to validate semantic evidence.

   **No fixed question count.** Well-specified tasks with clear scope may complete the Grill with 0 additional questions. Ambiguous tasks may require many rounds. Depth is driven by the Ambiguity Register, not by a preset count.

   **Each question MUST embed a recommended answer:** "I think X because Y — does that work?" This reduces decision fatigue. Explain reasoning and explicitly invite disagreement to avoid anchoring bias.

   **Exit announcement:**
   ```
   "Grill mode complete:
     Scope: [statement]
     Ambiguity Register: N resolved (M assumed, K deferred-out-of-scope)
     Assumption Ledger: M assumptions tracked
     Success criteria: [command evidence] + [semantic evidence]
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

7. **APPROVAL** — Present spec to user for confirmation using sectioned design approval: present section-by-section, get user confirmation per section. This ensures each design section (scope, approach, verification, risks) receives explicit user sign-off before proceeding.
   - On approval: **Auto-transition to Phase 2.**

---

## Phase 2: Write Plan

**Goal:** Produce a concrete, written implementation plan with expanded task schema.

**Procedure:**

1. Announce: "**Phase 2: Write Plan** — writing plan to `.claude/plans/`."

2. Write plan to `.claude/plans/YYYY-MM-DD_HHMMSS-<slug>.md`:
   - **Goal**: What we're building — concise one-liner
   - **Context**: Version, project type, key decisions from Phase 0/1
   - **Approach**: Step-by-step with exact file paths
   - **Files**: All files to create or modify, with expected changes
   - **Verification**: How we'll test each step
   - **Risks**: Known risks, tradeoffs, open questions
   - **Tasks**: JSON task block (```json:tasks) with expanded fields — for Phase 4 Workflow consumption

3. **Task Schema (expanded):** Each task in the `json:tasks` block MUST include:

   ```
   id, prompt, files, complexity, mutatesFiles,
   contextRefs, intakeRefs, grillRefs,
   expectedEvidence, forbiddenEvidence,
   patchBackStrategy
   ```

   | Field | Type | Description |
   |-------|------|-------------|
   | `id` | string | Unique task identifier |
   | `prompt` | string | Self-contained implementation instruction (subagent starts with blank context) |
   | `files` | string[] | Files this task creates or modifies |
   | `complexity` | string | `simple` \| `medium` \| `complex` |
   | `mutatesFiles` | boolean | Whether this task writes to the filesystem |
   | `contextRefs` | string[] | References to Phase 0/0.3 context artifacts this task depends on |
   | `intakeRefs` | string[] | References to Phase 0 Task Intake Snapshot entries relevant to this task |
   | `grillRefs` | string[] | References to Phase 1 Ambiguity Register or Assumption Ledger entries relevant to this task |
   | `expectedEvidence` | string[] | Specific evidence expected upon completion (e.g., `go build ./... exits 0`, `TestFoo passes`) |
   | `forbiddenEvidence` | string[] | Evidence that MUST NOT appear (e.g., `no new TODO comments`, `no import cycles`) |
   | `patchBackStrategy` | string | How changes flow back to the master tree |

   **patchBackStrategy values:**
   - `no-isolation`: Agent works directly in the current tree (simple, low-risk tasks)
   - `harness-managed`: Worktree isolation with harness-managed lifecycle; Phase 4.5 master agent reviews worktree diffs and merges back approved changes
   - `external-report`: Manual integration; task marked `DONE_WITH_CONCERNS` and requires human intervention

4. `Agent(description='Write implementation plan', prompt='Write the implementation plan to .claude/plans/<timestamp>-<slug>.md with Goal, Context, Approach, Files, Verification, Risks sections. Include a ```json:tasks fenced code block at the end with an array of task objects using the expanded schema: {id, prompt, files, complexity, mutatesFiles, contextRefs, intakeRefs, grillRefs, expectedEvidence, forbiddenEvidence, patchBackStrategy}. Each prompt must be a self-contained implementation instruction suitable for a subagent starting with blank context.', subagent_type='general-purpose')`

5. Auto-transition to Phase 3.

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
   - If `APPROVE` → proceed to step 5 (output task list)
   - If `ITERATE` → address findings → re-run Workflow (max 3 iterations)
   - If `REJECT` → present to user with reasons. Do NOT proceed.

5. **Output:** Bite-sized task list with file paths, expected changes, verification criteria.

6. Present the plan for user approval before proceeding.

7. Auto-transition to Phase 4.

---

## Phase 4: Implement (Workflow Pipeline)

**Goal:** Execute all implementation tasks in parallel using a deterministic Workflow script. Phase 4.5 handles worktree review, Phase 5 handles review, Phase 6 handles full verification.

**Important:** Workflow scripts CANNOT perform file I/O, Bash, or Read operations. They are pure orchestrators — they dispatch subagents and coordinate phases. All file operations happen through dispatched subagents. Isolation strategies are documented in the task schema (Phase 2).

**Procedure:**

1. **ANNOUNCE:** "**Phase 4: Implement** — Workflow(pipeline) via phase4-implement.js."

2. **LOAD TASKS:**
   - Read the Phase 3 plan from `.claude/plans/`
   - Extract the `json:tasks` fenced code block → parse JSON → get tasks array
   - Each task includes the expanded schema: `{id, prompt, files, complexity, mutatesFiles, contextRefs, intakeRefs, grillRefs, expectedEvidence, forbiddenEvidence, patchBackStrategy}`
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
     - mutatesFiles=true, patchBackStrategy='harness-managed' → isolation='worktree' (avoids file conflicts)
     - mutatesFiles=true, patchBackStrategy='no-isolation' → isolation='none' (agent works in current tree)
   - Stage 2 (Quick Verify): `agent(verify, {phase: 'Quick Verify', schema})` per task
     - Each task verified immediately after implementation (streaming — no waiting for other tasks)
     - Validates: build passes + affected tests pass

   The script includes a Self-Review stage: each implementer reports DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED. The script returns `selfReviewStatus` — pass this to Phase 5 as `args.selfReviewStatuses`. If budget.total is set, tasks are prioritized by complexity.

4. **Phase 4.5: Worktree Review (Master Agent):** After Phase 4 script completes and BEFORE Phase 5 review, the master agent MUST:
   - For every task with `patchBackStrategy='harness-managed'`: review the worktree diff, validate against `expectedEvidence` and verify no `forbiddenEvidence`, then merge back approved changes to the parent tree
   - For tasks with `patchBackStrategy='no-isolation'`: changes are already in-tree; verify `expectedEvidence`
   - For tasks with `patchBackStrategy='external-report'`: flag as `DONE_WITH_CONCERNS` and document what manual integration is needed

5. **REPORT** — auto-transition to Phase 5:
   ```
   "Phase 4: Implemented
   - Tasks: N/N completed, M passed, B failed
   - Worktree merges: N reviewed, M approved
   - Files: <count> changed
   → Phase 5."
   ```
   If failures → collect failed task IDs for Phase 5 review.

6. **ERROR RECOVERY:** If Workflow script throws → Read error from transcript → Agent fix script bug → re-run Workflow.

7. **Auto-transition** to Phase 4.6.

---

## Phase 4.6: Quick Gate (Master Agent)

**Goal:** Validate that Phase 4 output matches expected evidence before entering expensive
         Phase 5 review. Fail fast if evidence is missing.

**Procedure:**

1. `Bash(command='git diff --stat')` — confirm expected files changed. Compare against task files from Phase 2 plan. Flag missing or unexpected files.

2. **grep for expectedEvidence per task:** For each task with expectedEvidence entries, grep changed files for expected strings/patterns. Collect per-task results.

3. **grep for forbiddenEvidence per task:** For each task with forbiddenEvidence entries, grep changed files for forbidden strings/patterns. ANY match = FAIL.

4. **FAIL FAST:** If expectedEvidence missing → report which task + which evidence. If forbiddenEvidence found → report which task + which evidence. If unexpected files in diff → report. Return to Phase 4 to fix, OR proceed with documented concerns.

5. **ALL PASS → auto-transition to Phase 5.**

Input: tasks array from Phase 2 plan (with expectedEvidence + forbiddenEvidence), optional `.claude/state/grill-evidence.json` for cross-reference.

Output: `quickGateResults = {passed, perTask: {taskId: {expectedPassed, forbiddenClean, filesMatch}}}`.

---

## Phase 5: Two-Stage Review (ALWAYS RUNS)

**Goal:** Spec compliance review first → code quality review second. NEVER reverse order. Uses deterministic Workflow script for parallel code quality audit.

### Review Layers (P1 Optimization)

Phase 5 uses a 4-layer review model to minimize token consumption. Complexity from Phase 2 task schema drives gating.

| Layer | Name | Gates | Agent Calls |
|-------|------|-------|-------------|
| Layer 1 | Fast Gate | Master bash checks (files exist, git diff --stat, git diff --check, import check) — runs BEFORE phase5-review.js script | 0 agent calls |
| Layer 2 | Standard (Spec Review) | Gated by complexity: `simple` skips, `medium`/`complex` runs | 0-1 agent per task |
| Layer 3 | Deep (Code Quality) | Gated by complexity: `simple` skips entirely, `medium` gets correctness-only (1 agent), `complex` gets full 3-agent parallel | 0-3 agents per task |
| Layer 4 | Final (Cross-Task) | Conditional: skip when <2 tasks OR no shared files; run when >=2 tasks share files | 0-1 agent |

**Expected token savings: ~50-60%** for mixed-complexity runs vs. uniform full review.

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
   5. Reference file existence: `for ref in $(grep -oE 'references/[a-z0-9-]+\.md' skills/project-workflow-claude/SKILL.md); do test -f "skills/project-workflow-claude/$ref" && echo "✓ $ref" || echo "✗ MISSING: $ref"; done`

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
| 4 (Implement) | 4.5 (Worktree) | All tasks done + Phase 4.5 worktree review complete |
| 4.5 (Worktree) | 4.6 (Quick Gate) | All worktree merges complete |
| 4.6 (Quick Gate) | 5 (Review) | Quick Gate ALL PASS |
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

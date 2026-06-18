---
name: detecting-environment
description: Use when starting or resuming project-workflow-claude, or when the user asks to inspect a repository before design or implementation. Detects project type, language/tooling, MCP availability, context artifact freshness, and task-specific skill routing. In full-workflow mode, hands off to designing-solutions.
version: "v2.9"
---

# Detecting Environment

## Purpose

Detect project type, tooling, context artifacts, and task-specific skills before any design or implementation work. Combines the legacy Phase 0 (environment detection), Phase 0.3 (codebase analysis + knowledge layer), and Phase 0.5 (smart skill selection) into a single modular skill.

## Inputs

- User request from the current conversation.
- Optional `.claude/state/project-workflow-state.json` for resume scenarios.
- Repository files including `go.mod`, `package.json`, `skills/*/SKILL.md`, `CLAUDE.md`, `CONTEXT.md`, and `.claude/context/knowledge.md`.

## Procedure

### Step 0: State Validation

Read `.claude/state/project-workflow-state.json`.

Verify required fields per `skills/project-workflow-claude/references/state-validation.md`.

**Required for this phase:** `taskIntakePath`

- If any required field is missing or null: BLOCK. Report exactly what's missing.
- If `escapeHatchesUsed` is missing from state file: default to `[]` (backward compat).
- If all required fields present: continue to Step 1.

### Step 1: Detect Project Type

Check in order, first match wins. Use Glob with Bash fallback as noted.

1. `Glob(pattern='**/go.mod')` returns matches -- **Go project**
   *(fallback: `Bash(command='find . -name "go.mod" -type f 2>/dev/null | head -1')`)*
2. `Glob(pattern='**/package.json')` returns matches -- check for Vue/React:
   - `Grep(pattern='"vue"', path='package.json')` -- **Vue project**
   - `Grep(pattern='"react"', path='package.json')` -- **React project**
   - Otherwise -- **Node/JavaScript project**
3. `Glob(pattern='skills/*/SKILL.md')` returns matches -- **Skills Repository**
4. None of the above -- **Unknown** (answer with karpathy-guidelines only)

### Step 2: Detect Language and Tooling Versions

- **Go:** `Bash(command='grep "^go " go.mod | cut -d" " -f2')` for version; `Bash(command='which go && which golangci-lint')` for tooling
- **Vue/Node:** `Bash(command='node -v')` for version; check `tsconfig.json` for TypeScript; `Bash(command='which node && (which npm || which pnpm)')` for tooling
- **Skills Repository:** `Bash(command='which git')` -- text-only project, no language version

### Step 3: Detect MCP Availability

Check available tool names in the current session:
- Tool name contains "context7" (case-insensitive) -- Context7 MCP available
- Tool name contains "firecrawl" (case-insensitive) -- Firecrawl MCP available
- Neither available: document queries fallback to WebFetch; search fallback to WebSearch
- If missing but recommended: suggest consulting `skills/project-workflow-claude/references/setup.md` for installation

### Step 4: Task Intake Snapshot

Create or update `.claude/state/task-intake.json` with a structured snapshot:

```json
{
  "requestSummary": "<concise restatement of the user's request>",
  "repoRoot": "<absolute path to repo root>",
  "approvedInScope": ["<explicitly included deliverables>"],
  "approvedOutOfScope": ["<explicitly excluded items>"],
  "sourceEvidence": ["<references to messages, files, or decisions>"],
  "constraints": ["<known non-negotiables: language version, deps, platform>"]
}
```

- `requestSummary`: Concise restatement of the user's request as understood.
- `repoRoot`: Absolute path to the repository root.
- `approvedInScope`: Explicitly included deliverables and changes.
- `approvedOutOfScope`: Explicitly excluded items (prevents scope creep).
- `sourceEvidence`: References to messages, files, or decisions that support intake determinations.
- `constraints`: Known non-negotiables (language version, dependencies, platform requirements).

Delegate the file write to a subagent.

### Step 5: Context Artifact Freshness

Follow the context artifact model in `references/context-artifact-model.md`.

1. **Freshness check:**
   - `Read('.claude/context/knowledge.md')` -- read header commit SHA
   - `Read('CLAUDE.md')` -- read header commit SHA (if file exists)
   - `Read('CONTEXT.md')` -- read header commit SHA (if file exists)
   - `Bash(command='git rev-parse HEAD')` -- current SHA
   - Each artifact independently compared against HEAD
   - Match -- announce "Context artifacts fresh (commit <sha>), skipping analysis."
   - No match or no file -- proceed to analysis

2. **Analyze and write** (pipeline: 1 analysis agent → 2 parallel write agents):
   
   **Stage A — Analysis Agent** (1 agent, scans codebase once):
   - **Go project:** Analyze architecture: error handling patterns, DI approach, concurrency model, testing conventions. Map key entities with source paths. Output structured analysis JSON (entities, interfaces, package map, CLAUDE.md AUTO block content).
   - **Vue/Node project:** Analyze component tree, routing, state management, testing setup. Output structured analysis JSON.
   - **Skills Repository:** Analyze SKILL.md inventory by category, reference integrity, directory structure. Output structured analysis JSON with CLAUDE.md AUTO block content.
   
   **Stage B — Parallel Write Agents** (2 agents, consume analysis JSON):
   - **Agent B1:** Write CONTEXT.md (root) + `.claude/context/knowledge.md` (full overwrite). Follow `skills/project-workflow-claude/references/context-md-spec.md` for CONTEXT.md format (KNOWLEDGE_START/END + INSTRUCTION_START/END markers). Header: `<!-- Auto-generated | Commit: <sha> | Date: <iso> | <type> -->`.
   - **Agent B2:** Update CLAUDE.md. If absent: write full skeleton with AUTO_START/AUTO_END markers for Project and Commands sections. If present: inspect AUTO markers and update content from analysis JSON. Surface warnings for malformed markers.
   
   Dispatch B1 and B2 in parallel after Stage A completes.

3. **Cross-validation** (lightweight):
   - Sample 3-5 source paths from analysis — use `Read(file_path='<path>')` to verify existence
   - For Go: architecture claims vs `Grep` in `go.mod`
   - Log failures but don't block

### Step 6: Intelligent Skill Selection (Two-Step Routing)

Master builds a candidate pool from ALL available skills, then applies judgment to select the final set. Don't load every match — load only what the task genuinely needs.

#### 6a. Discover Available Skills (Both Sources)

1. **Project skills:** List `skills/*/SKILL.md` directories. Read frontmatter (name + description) for each. These are the 23 skills shipped with jessy-skills.
2. **Global skills:** List `~/.claude/skills/*/SKILL.md` entries. Read frontmatter for each. These include user-installed plugins (superpowers, omc, grill-me, etc.) and manually added skills. Skip symlinks that already point to project skill dirs (dedup by resolved path).

#### 6b. Build Candidate Pool (Mechanical Scan)

Load the routing overlay: `Read('skills/project-workflow-claude/references/claude-routing.md')`.

**Codebase signals:**
- **Go:** Scan `go.mod` for framework keywords (samber, grpc, testify, cobra, viper, etc.). Match against `claude-routing.md` (overlay) and project-go skills.
- **Vue:** Scan `package.json` for vue, pinia, vitest, vue-router. Match against routing tables.
- **Skills Repo:** No codebase signals — task signals only.

**Task signals:**
- Scan the user's request for keywords matching `claude-routing.md` task signal table (implement, review, verify, design, commit, debug, etc.). Add matched skills to candidate pool.

**Memory triggers:**
- Scan `~/.claude/projects/.../memory/` for `→ load skill <name>`. Add matched skills.

**MCP awareness:**
- If Context7 available → note for docs/library queries.
- If Firecrawl available → note for web searches.

#### 6c. Master Judgment (Filter Candidates)

For each candidate in the pool, Master answers:

1. Does the task actually involve this skill's domain? (not just keyword match in go.mod)
2. Is the skill likely to provide actionable guidance in this session?

**Discard candidates** that fail both checks. Document the reason.

**Force-load candidates** that pass. `Skill(skill='<name>')` for each.

#### 6d. Baseline (Always Load)

`karpathy-guidelines` — Think before coding, surgical changes, fresh evidence. Never skip.

#### 6e. Iron Law

If the task involves code changes or verification: `Read('skills/project-workflow-claude/references/iron-law.md')`.

#### 6f. Log the Selection

Record in the announcement:
```
Phase 0.5: Intelligent Skill Selection
- Scanned: N project + M global = T total skills available
- Candidates: K matched (codebase: X, task: Y, memory: Z)
- Master judgment: L loaded, D discarded
- Discarded: skill-A (no DB work in task), skill-B (...)
- Baseline: karpathy-guidelines
```

### Step 7: Persist Context Summary

Write `.claude/state/context-summary.json` (delegate to subagent):

```json
{
  "rootContextPath": "CONTEXT.md",
  "rootContextStatus": "present | missing | created | updated",
  "nearestContextPaths": [],
  "knowledgePath": ".claude/context/knowledge.md",
  "knowledgeStatus": "fresh | stale | generated",
  "contextWarnings": [],
  "confirmedFacts": [],
  "autoFacts": [],
  "projectType": "go | vue | node | skills-repo | unknown",
  "loadedSkills": []
}
```

- `rootContextStatus`: `present` (up-to-date), `missing` (does not exist), `created` (newly generated), `updated` (refreshed sections)
- `nearestContextPaths`: list of scoped subdirectory CONTEXT.md files found (sorted by depth, nearest first)
- `knowledgeStatus`: `fresh` (commit matches), `stale` (commit mismatch), `generated` (newly written)
- `contextWarnings`: contradiction warnings, malformed marker warnings, stale evidence
- `confirmedFacts`: key `[confirmed]` facts loaded from CONTEXT.md
- `autoFacts`: key `[auto]` facts loaded from CONTEXT.md
- `projectType`: normalized project type token (`go`, `vue`, `node`, `skills-repo`, `unknown`)
- `loadedSkills`: array of skill names loaded in Step 6

### Announce Results

```
"Phase 0: Environment -- [type], [version]
Tooling: [available tools]
MCP: context7 [available/not available], firecrawl [available/not available]

Phase 0.3: Codebase Analysis -- [project-type], commit <sha>
CONTEXT.md: [present|missing|created|updated]
Knowledge Layer: [fresh|stale|generated] -- N patterns, N entities, N interfaces
CLAUDE.md: [fresh | generated | updated (N blocks) | skipped (malformed markers) | upgraded (first-touch AUTO markers added)]
Cross-validation: [pass/fail details]

Phase 0.5: Intelligent Skill Selection
- Scanned: N project + M global = T total skills available
- Candidates: K matched (codebase: X, task: Y, memory: Z)
- Master judgment: L loaded, D discarded
- Discarded: <list with reasons>
- Baseline: karpathy-guidelines"
```

## Output Contract

Write `.claude/state/context-summary.json` with the shape defined in Step 7. Update `.claude/state/project-workflow-state.json` with `contextSummaryPath` and `currentSkill`.

## Exit Contract

1. Update `.claude/state/project-workflow-state.json`:
   - `lastCompletedSkill="detecting-environment"`
   - `currentSkill="designing-solutions"`
   - `nextSkill="planning-implementation"`
   - `contextSummaryPath=".claude/state/context-summary.json"`

2. If `handoffPolicy=auto-continue`, announce and invoke `Skill(skill='designing-solutions')`:
   ```
   "Environment/context setup complete.
   --> Continuing full workflow: invoking /designing-solutions."
   ```

3. If standalone (invoked directly by user), print:

```text
Environment/context setup complete.

Recommended next step:
1. /designing-solutions (Recommended) -- turn the request into an approved design before planning or code.
2. /project-workflow-claude continue -- resume the full workflow from this point.
3. Stop here -- keep the environment/context artifacts only.
```

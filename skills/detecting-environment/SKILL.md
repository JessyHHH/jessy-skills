---
name: detecting-environment
description: Use when starting or resuming project-workflow-claude, or when the user asks to inspect a repository before design or implementation. Detects project type, language/tooling, MCP availability, context artifact freshness, and task-specific skill routing. In full-workflow mode, hands off to designing-solutions.
version: "v2.7"
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
- If missing but recommended: suggest consulting `references/setup.md` for installation

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

2. **Analyze and write** (delegate to a single Agent subagent):
   - **Go project:** Analyze architecture: error handling patterns, DI approach, concurrency model, testing conventions. Map key entities with source paths. Write CONTEXT.md (root) following the format spec in `skills/project-workflow-claude/references/context-md-spec.md` with KNOWLEDGE_START/KNOWLEDGE_END and INSTRUCTION_START/INSTRUCTION_END markers. Write `.claude/context/knowledge.md` (full overwrite). Header: `<!-- Auto-generated | Commit: <sha> | Date: <iso> | Go <version> -->`.
   - **Vue/Node project:** Analyze component tree, routing, state management, testing setup. Map key components with source paths. Write CONTEXT.md (root) and `.claude/context/knowledge.md` (full overwrite). Header format as above with appropriate project type.
   - **Skills Repository:** Analyze SKILL.md inventory by category, reference integrity, directory structure. Write CONTEXT.md (root) and `.claude/context/knowledge.md`. Also check/create CLAUDE.md: if absent, write full skeleton with AUTO_START/AUTO_END markers for Project and Commands sections; if present, inspect AUTO markers and update or surface warnings per `references/context-artifact-model.md`.

3. **Cross-validation** (lightweight):
   - Sample 3-5 source paths from analysis — use `Read(file_path='<path>')` to verify existence
   - For Go: architecture claims vs `Grep` in `go.mod`
   - Log failures but don't block

### Step 6: Skill Selection

1. **Load platform overlay:** `Read('skills/project-workflow-claude/references/claude-routing.md')` -- load Claude Code-specific action mappings.

2. **Codebase signal matching** (from dependency scan):
   - **Go:** `Read('go.mod')` -- scan for samber, grpc, testify, etc. -- match against `skills/project-workflow/references/full-skill-routing.md` (base layer, shared) and `skills/project-workflow-claude/references/claude-routing.md` (overlay)
   - **Vue:** `Read('package.json')` -- scan for vue, pinia, vitest -- match against routing tables
   - For EVERY match: `Skill(skill='<name>')`

3. **MCP-aware routing:** If Context7 available -- prefer for docs/library queries. If Firecrawl available -- prefer for web searches.

4. **Task signal matching:** Match keywords against `full-skill-routing.md` and `claude-routing.md`. Load each matched skill via `Skill(skill='<name>')`.

5. **Memory trigger detection:** Scan `~/.claude/projects/.../memory/` for the pattern `(arrow) load skill <name>` (using the actual arrow character). Load matched skills via `Skill(skill='<name>')`. Skip already-loaded skills.

6. **Baseline** (no Skill calls, internalized): `karpathy-guidelines` -- Think before coding, surgical changes, fresh evidence.

7. **Deduplication:** Skip already-loaded skills. If both base layer and overlay match the same skill name, log collision and use overlay.

8. **Iron Law loading:** If task involves code changes or verification -- `Read('skills/project-workflow-claude/references/iron-law.md')`.

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

Phase 0.5: Skills
- Codebase signals: N skills loaded
- Task signals: N skills loaded
- Overlay: claude-routing.md loaded
- Total: N skills"
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

# Workflow Context Enrichment — Implementation Plan

## Goal
Fix Phase 4 sub-agent "missing complete context" issue. Sub-agents currently receive only reference names (file names, decision keys) instead of actual content. Since sub-agents start with blank context, they fail to implement complex code modification tasks.

## Context
- Skills Repository, commit 81e2b8d
- Key decisions from Grill Phase 1:
  - Master agent enriches context before calling Workflow (scripts can't do I/O)
  - Embed FULL file contents (1M context window, no token budget constraint)
  - Phase 3 and Phase 4 share the same enriched data
  - All new fields optional (backward compatible)

## Enrichment Algorithm (Master Agent)

The Master agent executes this algorithm in Phase 4 step 3 (ENRICH TASKS) before calling the workflow:

```javascript
// For EACH task in parsed tasks array:
for each task in tasks:
  // a. Read target files → fileContents
  fileContents = []
  for each file in task.files:
    content = Read(file)
    fileContents.push({file: file, content: content})

  // b. Resolve grill refs → grillDecisions (if grill-evidence.json exists)
  grillDecisions = []
  if .claude/state/grill-evidence.json exists:
    evidence = Read(.claude/state/grill-evidence.json)
    for each refKey in task.grillRefs:
      match = find in evidence.ambiguityRegister by id=refKey
           || find in evidence.assumptionLedger by id=refKey
      if match:
        decision = match.decision || (match.assumption + " (confidence: " + match.confidence + ")")
        grillDecisions.push({key: refKey, decision: decision})

  // c. Extract plan sections → planSections
  // Include the Approach and Verification subsections from the plan,
  // filtered to lines that mention any of task.files or task.id
  // If no specific match, include the entire Approach section

  // d. Build enriched task
  enrichedTask = copy(task)
  enrichedTask.fileContents = fileContents
  enrichedTask.grillDecisions = grillDecisions
  enrichedTask.planSections = planSections
```

## Constraints & Limitations

**Token budget (per task):** Each sub-agent has a 1M context window. With ~2000 chars of task prompt + N files × ~500 lines × ~50 chars/line, a single task can safely embed 5-8 full files (~200K chars). For tasks with more files, embed only the files the task directly modifies (task.files), not contextRefs files.

**Worktree isolation:** When `patchBackStrategy='harness-managed'`, the sub-agent runs in an isolated worktree. Enrichment still works because `fileContents` is embedded directly in the agent prompt string — the sub-agent receives the code content inline, not as file paths. The sub-agent uses the embedded code to understand the codebase, then reads/writes in its worktree. This is NOT a conflict.

**Stale content in parallel tasks:** Enrichment happens once before Phase 4 starts. If Task A modifies a shared file and Task B reads the same file, Task B receives pre-modification (stale) content. **Constraint:** Tasks with file-level cross-dependencies MUST be serialized (single task or sequential execution) rather than run in parallel pipeline. The pipeline is safe when tasks modify disjoint file sets.

**ContextRefs vs fileContents:** `contextRefs` files (e.g., `knowledge.md`, `specs/design.md`) are context artifacts the sub-agent should understand but NOT modify. These are NOT included in `fileContents` (which is derived from `task.files`). The Master should read contextRefs files and embed their content in `planSections` or provide them as additional `fileContents` entries. Without enrichment, contextRefs remain as bare file name references (the original bug). **For this implementation (2 files, self-contained project), contextRefs are empty for both tasks — no gap.**

**Enrichment validation:** When `fileContents` is empty AND `contextRefs` has entries, the script emits a contextual log message to warn that enrichment may have been skipped. The fallback behavior is preserved for backward compatibility.

## Files Changed

### 1. `~/.claude/workflows/phase4-implement.js`

**Change:** Enhance `buildImplementerPrompt()` (lines 60-104)

**New optional task fields:**
- `fileContents`: Array of `{file: string, content: string}` — full file contents the task modifies
- `grillDecisions`: Array of `{key: string, decision: string}` — resolved grill decisions by key
- `planSections`: String — relevant plan sections for this task

**How:** After the existing `grillRefs` block (line 80-81), add new blocks that check for these fields. When present, embed content directly into prompt under `## Current Code`, `## Design Decisions`, `## Relevant Plan Sections` headings. When absent, fall back to existing reference behavior.

**Default init:** Add `t.fileContents = t.fileContents || []`, `t.grillDecisions = t.grillDecisions || []`, `t.planSections = t.planSections || ''` to the extend-task-schema block (lines 18-28).

**Backward compatible:** All new fields are optional. If not provided by Master, prompt building falls back to existing reference-based behavior.

### 2. `skills/project-workflow-claude/SKILL.md`

**Changes in 3 sections:**

#### Phase 2 (line ~466): Task Schema table — add 3 new optional rows

Add to the task schema table after `patchBackStrategy`:
```
| `fileContents` | object[] | (Optional) Full file contents. Each: `{file: string, content: string}`. Master fills before Phase 4. |
| `grillDecisions` | object[] | (Optional) Resolved grill decisions. Each: `{key: string, decision: string}`. Master fills before Phase 4. |
| `planSections` | string | (Optional) Relevant plan sections for this task. Master fills before Phase 4. |
```

Also update the `contextRefs` and `grillRefs` descriptions to note they serve as fallback references when Master doesn't enrich.

#### Phase 3 (line ~508-514): Judge Panel Review — require enrichment

Replace the current `Workflow(name='phase3-consensus', args={planContent: '...'})` call with enriched version:

```
Workflow(
  name='phase3-consensus',
  args={
    planContent: '<full plan text>',
    contextSummary: <Phase 0.3 output contextSummary>,
    grillSummary: <Phase 1 grill evidence — ambiguity register + assumption ledger>,
    taskIntakeSnapshot: <Phase 0 task intake snapshot>,
    tasks: <parsed tasks array from plan>
  }
)
```

Add instruction: "Master MUST collect contextSummary, grillSummary, taskIntakeSnapshot, and tasks before calling Phase 3. These enable pre-check validation (scope contradiction, ambiguity resolution, task contract)."

#### Phase 4 (line ~538-552): LOAD TASKS + EXECUTE — require enrichment

Replace the current `Workflow(name='phase4-implement', args={tasks: [...]})` with enriched version. Add BEFORE the EXECUTE section a new step "ENRICH TASKS":

```
2.5. **ENRICH TASKS (Master Agent):**
   For each task in the tasks array:
   a. Read all task.files (full file contents) → build fileContents array
   b. Read `.claude/state/grill-evidence.json` (if exists) → resolve task.grillRefs keys into grillDecisions
   c. Read the plan → extract sections relevant to this task → planSections string
   d. Build enriched task object with fileContents, grillDecisions, planSections embedded

   Each enriched task MUST be self-contained — subagent starts with blank context and only receives this prompt. Budget note: use full file contents, not just summaries (subagents have 1M context windows).
```

## Verification
- Verify `bash tests/test-*.sh` passes after changes
- Verify `git diff --check` clean

## Risks
- Low risk: all new fields optional, zero breaking change
- Low risk: enriched prompts are larger but within 1M context budget

## Tasks

```json:tasks
[
  {
    "id": "task-01",
    "prompt": "## Task: Enhance buildImplementerPrompt() in phase4-implement.js\n\nEdit the file `/home/huangzexi/.claude/workflows/phase4-implement.js`.\n\n### Changes\n\n1. **Default init block (lines 18-28):** Add 3 new default initializations:\n   ```javascript\n   t.fileContents = t.fileContents || []\n   t.grillDecisions = t.grillDecisions || []\n   t.planSections = t.planSections || ''\n   ```\n\n2. **buildImplementerPrompt() function (lines 60-104):** After the grillRefs block (lines 78-81), add 3 new content embedding blocks BEFORE the evidence contract block:\n\n   a. **fileContents block:** If `task.fileContents` is non-empty array, embed each file's content:\n      ```javascript\n      // Full file contents (provided by Master enrichment)\n      if (task.fileContents && task.fileContents.length > 0) {\n        parts.push('\\n## Current Code (provided by orchestrator)\\n')\n        task.fileContents.forEach(function(fc) {\n          parts.push('### File: ' + fc.file)\n          parts.push('```\\n' + fc.content + '\\n```')\n        })\n      }\n      ```\n\n   b. **grillDecisions block:** If `task.grillDecisions` is non-empty array, embed each decision:\n      ```javascript\n      // Resolved grill decisions (provided by Master enrichment)\n      if (task.grillDecisions && task.grillDecisions.length > 0) {\n        parts.push('\\n## Design Decisions (from Grill)\\n')\n        task.grillDecisions.forEach(function(d) {\n          parts.push('### ' + d.key)\n          parts.push(d.decision)\n        })\n      }\n      ```\n\n   c. **planSections block:** If `task.planSections` is non-empty string, embed it:\n      ```javascript\n      // Relevant plan sections (provided by Master enrichment)\n      if (task.planSections) {\n        parts.push('\\n## Relevant Plan Sections\\n')\n        parts.push(task.planSections)\n      }\n      ```\n\n   d. **Fallback for contextRefs:** Change the existing contextRefs block (lines 64-66) to only fire when fileContents is NOT provided:\n      ```javascript\n      // Context files (fallback when Master doesn't provide fileContents)\n      if ((!task.fileContents || task.fileContents.length === 0) && task.contextRefs && task.contextRefs.length > 0) {\n        parts.push('\\nConsider these context files: ' + JSON.stringify(task.contextRefs))\n      }\n      ```\n\n   e. **Fallback for grillRefs:** Change the existing grillRefs block (lines 78-81) to only fire when grillDecisions is NOT provided:\n      ```javascript\n      // Grill decisions (fallback when Master doesn't provide grillDecisions)\n      if ((!task.grillDecisions || task.grillDecisions.length === 0) && task.grillRefs && task.grillRefs.length > 0) {\n        parts.push('\\nRelevant decisions: ' + JSON.stringify(task.grillRefs))\n      }\n      ```\n\n3. **Update comment on lines 11-13:** Update the arg parsing comment to list the new optional fields:\n   ```javascript\n   // Parse args with expanded task fields from Phase 2/3:\n   // {tasks: [{id, prompt, files, complexity, mutatesFiles, contextRefs, intakeRefs,\n   //   grillRefs, fileContents, grillDecisions, planSections,\n   //   expectedEvidence, forbiddenEvidence, patchBackStrategy}]}\n   ```\n\n### Verification\n- Run `node -c ~/.claude/workflows/phase4-implement.js` to verify syntax\n- Verify that existing fields (contextRefs, grillRefs) still work when new fields are absent\n- Verify that new fields (fileContents, grillDecisions, planSections) are embedded when present\n\n### Important\n- Match existing code style: 2-space indent, `var` declarations, `//` comments\n- Use `Array.isArray()` for array checks, `.length > 0` for non-empty checks\n- No ES6+ features (arrow functions are OK since they're already used in the file)\n- Template literals are OK (already used in the file)",
    "files": ["/home/huangzexi/.claude/workflows/phase4-implement.js"],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [],
    "intakeRefs": [],
    "grillRefs": ["A1-MasterEnriches", "A2-FullFileContents", "S1-1MContextBudget"],
    "expectedEvidence": ["buildImplementerPrompt() accepts fileContents, grillDecisions, planSections optional fields", "fileContents embedded under ## Current Code heading", "grillDecisions embedded under ## Design Decisions heading", "planSections embedded under ## Relevant Plan Sections heading", "contextRefs fallback fires only when fileContents absent", "grillRefs fallback fires only when grillDecisions absent", "node -c exits 0"],
    "forbiddenEvidence": ["no ES6+ features (let, const, for...of, destructuring)", "no removal of existing fields"],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "task-02",
    "prompt": "## Task: Update SKILL.md — Phase 2, 3, 4 sections\n\nEdit the file `/home/huangzexi/personal/jessy-skills/skills/project-workflow-claude/SKILL.md`.\n\n### Changes\n\n#### 1. Phase 2 Task Schema table (after line ~487, after patchBackStrategy row)\n\nAdd 3 new rows to the task schema table. After the `patchBackStrategy` row, before the closing of the table:\n\n```markdown\n| `fileContents` | object[] | (Optional) Full file contents for embedding in sub-agent prompt. Each: `{file: string, content: string}`. Master fills before Phase 4 via Read of task.files. |\n| `grillDecisions` | object[] | (Optional) Resolved grill decisions by key. Each: `{key: string, decision: string}`. Master fills from `.claude/state/grill-evidence.json`. |\n| `planSections` | string | (Optional) Plan sections relevant to this task. Master extracts from plan before Phase 4. |\n```\n\nAlso update the `contextRefs` description to note: \"Used as fallback references when `fileContents` is not provided.\"\nAlso update the `grillRefs` description to note: \"Used as fallback references when `grillDecisions` is not provided.\"\n\n#### 2. Phase 3 (lines 508-514) — Enrichment requirement\n\nReplace:\n```\n   Workflow(\n     name='phase3-consensus',\n     args={planContent: '<full plan text>'}\n   )\n```\n\nWith:\n```\n   Workflow(\n     name='phase3-consensus',\n     args={\n       planContent: '<full plan text>',\n       contextSummary: <Phase 0.3 output contextSummary>,\n       grillSummary: <Phase 1 grill evidence — ambiguity register + assumption ledger>,\n       taskIntakeSnapshot: <Phase 0 task intake snapshot>,\n       tasks: <parsed tasks array from plan>\n     }\n   )\n```\n\nAnd add BEFORE step 2:\n```\n1.5. **COLLECT CONTEXT:** Master agent MUST collect the following before calling the workflow:\n   - `contextSummary`: From Phase 0.3 output (structured JSON with rootContextPath, knowledgeStatus, confirmedFacts, etc.)\n   - `grillSummary`: From Phase 1 `.claude/state/grill-evidence.json` (ambiguityRegister + assumptionLedger)\n   - `taskIntakeSnapshot`: From Phase 0 Task Intake Snapshot\n   - `tasks`: Parsed tasks array from the plan's `json:tasks` block\n   These enable pre-check validation: scope contradiction detection, ambiguity resolution, and task contract validation (mutating tasks must have patchBackStrategy, tasks must have expectedEvidence or verification explanation).\n\n   If `.claude/state/grill-evidence.json` does not exist (simple tasks may skip Grill), pass `null` for grillSummary and document the omission in contextWarnings.\n```\n\n#### 3. Phase 4 (lines 538-552) — Enrichment requirement\n\nReplace the current step 2 \"LOAD TASKS\" and step 3 \"EXECUTE\" with:\n\n```\n2. **LOAD TASKS:**\n   - Read the Phase 3 plan from `.claude/plans/`\n   - Extract the `json:tasks` fenced code block → parse JSON → get tasks array\n   - Each task includes the expanded schema: `{id, prompt, files, complexity, mutatesFiles, contextRefs, intakeRefs, grillRefs, expectedEvidence, forbiddenEvidence, patchBackStrategy}`\n\n3. **ENRICH TASKS (Master Agent — REQUIRED):**\n   For each task in the tasks array:\n\n   a. **Read target files:** Use `Read()` on every file in `task.files`. Build `fileContents` array:\n      ```javascript\n      fileContents: [\n        {file: \"internal/repository/store.go\", content: \"<full file content>\"},\n        ...\n      ]\n      ```\n      Embed the COMPLETE file content, not just summaries. Sub-agents have 1M context windows — token budget is not a constraint.\n\n   b. **Resolve grill decisions:** Read `.claude/state/grill-evidence.json` (if exists). For each key in `task.grillRefs`, find the matching entry in ambiguityRegister or assumptionLedger, and build `grillDecisions` array:\n      ```javascript\n      grillDecisions: [\n        {key: \"Q1-ConfigRouting\", decision: \"Two MySQL configs: admin stays in yunui_mixyun, tenants use rag_tenant_db...\"},\n        ...\n      ]\n      ```\n      Resolution: match grillRefs key against ambiguityRegister[].id or assumptionLedger[].id. Extract the `decision` field (for register) or `assumption`+`evidence`+`confidence` fields (for ledger).\n\n   c. **Extract plan sections:** Read the plan. For each task, extract the approach steps and verification sections relevant to this task's scope. Build `planSections` string.\n\n   d. **Build enriched task object:** Each enriched task MUST be self-contained — the sub-agent starts with blank context and only receives this prompt. The `buildImplementerPrompt()` function in `phase4-implement.js` embeds `fileContents`, `grillDecisions`, and `planSections` under dedicated headings when present.\n\n4. **EXECUTE:**\n   ```\n   Workflow(\n     name='phase4-implement',\n     args={tasks: enrichedTasks}\n   )\n   ```\n\n   The script uses `pipeline()` (streaming, no barrier):\n   - Stage 1 (Implement): `agent(task.prompt, {model, isolation})` per task\n     - `buildImplementerPrompt()` embeds fileContents/grillDecisions/planSections when present\n     - Falls back to contextRefs/grillRefs references when absent (backward compatible)\n     - complexity='simple' → haiku, 'medium' → sonnet, 'complex' → sonnet\n     - mutatesFiles=true, patchBackStrategy='harness-managed' → isolation='worktree'\n     - mutatesFiles=true, patchBackStrategy='no-isolation' → isolation='none'\n   - Stage 2 (Quick Verify): `agent(verify, {phase: 'Quick Verify', schema})` per task\n   - Stage 3 (Self-Review): Each implementer reports DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED\n```\n\n#### 4. Anti-patterns section (line ~926)\n\nUpdate the existing anti-pattern #12:\n```\n12. ❌ Pass incomplete prompt to Phase 4 task — subagent starts with blank context; Master MUST enrich with fileContents, grillDecisions, and planSections\n```\n\n#### 5. Version tag\n\nUpdate version from v2.4 to v2.5 in the YAML frontmatter (line 4): `version: \"v2.5\"`\n\nAnd in the heading (line 20): `# Project Workflow Claude v2.5`\n\n### Important\n- Match existing markdown style (tables, code blocks, inline code)\n- Preserve all existing content outside the changed sections\n- Do NOT change Phase 5, Phase 6, or other phases\n- The task schema table uses `\\|` for pipe characters inside table cells",
    "files": ["/home/huangzexi/personal/jessy-skills/skills/project-workflow-claude/SKILL.md"],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [],
    "intakeRefs": [],
    "grillRefs": ["A1-MasterEnriches", "A2-FullFileContents", "A3-Phase3AlsoFixed"],
    "expectedEvidence": ["Phase 2 task schema table includes fileContents, grillDecisions, planSections rows", "Phase 3 calls Workflow with contextSummary, grillSummary, taskIntakeSnapshot, tasks args", "Phase 4 has ENRICH TASKS step before EXECUTE", "Phase 4 LOAD TASKS step describes reading target files, resolving grill decisions, extracting plan sections", "Version updated to v2.5 in frontmatter and heading", "Anti-pattern #12 updated"],
    "forbiddenEvidence": ["no changes to Phase 5, 6, 0, 1 sections", "no removal of existing content"],
    "patchBackStrategy": "no-isolation"
  }
]
```

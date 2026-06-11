# Implementation Plan: Workflow Frontload for Phase 1-3 + Handoff Hardening

**Status:** Draft (v3 — Consensus Round 2 fixes)
**Date:** 2026-06-10
**Spec:** `.claude/specs/2026-06-10-workflow-frontload-design.md`

## 1. Goal

7 tasks, 16 files: 2 new Workflow scripts, context dedup Phase 4→5 (Phase 4 side only — Phase 5 already reads from input first), state validation at 7 boundaries, Phase 6 mandatoryNextAction contract, Phase 4 task completion guarantee.

## 2. Context

- **Project:** jessy-skills (Skills Repository, 77 skills)
- **Workflow:** project-workflow-claude v2.7 → v2.8 — 7-skill modular pipeline
- **Branch:** claude, commit 48c7517
- **Key decisions:**
  - designing-solutions stays pure Skill (needs AskUserQuestion)
  - Phase 6: master agent re-runs Bash each iteration; script tracks dryRounds, returns `mandatoryNextAction`
  - Phase 4: 3 internal retry rounds (per-pipeline), 2 compensation loops (master level)
  - **T3 scope corrected** (Round 2 finding): `phase5-review.js` L340 `constructDiff()` already returns `task.diffText || 'DIFF NOT AVAILABLE...'`. L219 `enrichTaskForReview()` already checks `task.fileContents` first. T3 ONLY modifies `phase4-implement.js` — add diffText to implementer schema + perTaskDiffs/fileContentsSnapshots to output. Zero changes to phase5-review.js.
  - **T2 split-brain resolved** (Round 2 finding): SKILL.md Step 2: calls Workflow → Workflow generates plan + validates → SKILL.md writes returned `planContent` to `.claude/plans/` via subagent. No duplicate generation.
  - **T3+T6 merge resolved** (Round 2 finding): T3 adds extended output fields; T6 adds Stage 4. T6 applied AFTER T3. Stage 4 doesn't touch output fields T3 adds. No conflict.

## 3. Approach

### T1: Create `~/.claude/workflows/phase1-detect-knowledge.js` + `skills/project-workflow-claude/references/state-validation.md`

phase1-detect-knowledge.js orchestrates Steps 5-7 of detecting-environment:
- Input: `{projectType, commitSha, branchName, contextMdExists, knowledgeMdExists, claudeMdExists, allFresh}`
- Phase Analyze: 2 agents in parallel — codebase architecture analysis, skill inventory analysis
- Phase Select: 1 agent selects skills from codebase/task signals
- Phase Synthesize: 1 agent synthesizes contextSummary + loadedSkills
- Output: `{contextSummary, loadedSkills, contextWarnings}`
- The SKILL.md Steps 1-4 (Bash/Glob/Read) run BEFORE invoking this script. The script only receives their outputs.

state-validation.md: per-phase required fields table + skip-design logic (see T4).

### T2: Create `~/.claude/workflows/phase2-plan-generate.js`

Orchestrates Steps 2-4 of planning-implementation. **Choreography (split-brain resolved):**
1. SKILL.md reads spec + context files
2. SKILL.md calls `Workflow(name='phase2-plan-generate', args={specContent, contextSummary, grillSummary, taskIntake})`
3. Workflow generates plan in-memory (agent), validates schema (programmatic), enriches context (agent)
4. Workflow returns `{planContent, tasks, enrichedContext, validationErrors}`
5. SKILL.md delegates writing `planContent` to `.claude/plans/` via ONE subagent

The SKILL.md does NOT call its own plan-generating subagent — it uses the Workflow for generation. No duplication.

### T3: Context Dedup Phase 4→5 (Phase 4 side only)

**CORRECTED (Round 2):** `phase5-review.js` L340 `constructDiff()` already returns `task.diffText || 'DIFF NOT AVAILABLE...'`. L219 `enrichTaskForReview()` already checks `task.fileContents` first. Phase 5 already reads from input first with disk fallback.

ONLY modify `~/.claude/workflows/phase4-implement.js`:
- Stage 1 implementer schema: add `diffText` field
- After pipeline: collect `taskDiffs[task.id] = implResult.diffText` and `taskFileSnapshots[task.id]` from implementer output
- Return: add `perTaskDiffs` and `fileContentsSnapshots` to output contract

Zero changes to phase5-review.js — it already consumes these fields.

### T4: State Validation at 7 Phase Boundaries

MODIFY 7 skill SKILL.md files — each gets "Step 0: State Validation" section:

| Skill | Required State Fields | Additional Guard |
|-------|----------------------|-----------------|
| detecting-environment | taskIntakePath | None (first phase) |
| designing-solutions | contextSummaryPath | None |
| planning-implementation | contextSummaryPath | Block if BOTH specPath AND grillEvidencePath null AND "skip design" NOT in escapeHatchesUsed |
| implementing-changes | planPath | None |
| reviewing-implementation | quickGateResultsPath | None |
| verifying-completion | reviewResultsPath | None |
| finishing-development | verificationResultsPath | None |

Also MODIFY: orchestrator SKILL.md (references table), transition-rules.md (skip-design docs), state.json (escapeHatchesUsed field).
Back-compat: existing state files without `escapeHatchesUsed` — default to `[]`, don't block.

### T5: Phase 6 Loop Contract

MODIFY `~/.claude/workflows/phase6-verify.js`: add `mandatoryNextAction` enum to return. `totalIterations` tracking. Max 10 iterations guard. `verdict: "PASSED" | "EXHAUSTED" | "IN_PROGRESS"`.

MODIFY `skills/verifying-completion/SKILL.md` Step 4: mechanical loop using `mandatoryNextAction`. Master agent runs checks → passes to script → reads `mandatoryNextAction` → if RE_RUN_CHECKS, re-runs Bash and calls again. Aligned with design spec: "Master agent still runs Bash".

### T6: Phase 4 Completion Guarantee

MODIFY `~/.claude/workflows/phase4-implement.js`: new Stage 4 after Stage 3. Collects tasks with status NOT 'DONE'/'DONE_WITH_CONCERNS'. Retries with fresh agent (different strategy). Max 3 retry rounds, 50k token budget advisory. Retry is per-incomplete-task — already-DONE tasks are untouched. STUCK tasks returned with `stuckReason`. Failure cascade: per-task retry (not whole-pipeline abort).

MODIFY `skills/implementing-changes/SKILL.md`: Step 4b compensation loop (max 2, master level). Reads files to enrich stuck tasks, re-invokes Workflow with ONLY stuck tasks.

### T7: Update Orchestrator + Install

MODIFY orchestrator SKILL.md: v2.7→v2.8, Workflow Scripts table (add phase1/phase2 entries), Global Rules add #7. Update state.json initialization in Start/Resume to include `escapeHatchesUsed: []` and `version: "v2.8"`.

MODIFY `install.sh`: add cp commands for phase1-detect-knowledge.js and phase2-plan-generate.js (follow existing pattern).

## 4. Files

| File | Action | Expected Change |
|------|--------|-----------------|
| `~/.claude/workflows/phase1-detect-knowledge.js` | CREATE | 3-phase Workflow: Analyze→Select→Synthesize |
| `~/.claude/workflows/phase2-plan-generate.js` | CREATE | 3-phase Workflow: Generate→Validate→Enrich |
| `skills/project-workflow-claude/references/state-validation.md` | CREATE | Per-phase required fields table, skip-design logic |
| `~/.claude/workflows/phase4-implement.js` | MODIFY | +diffText/fileContentsSnapshot (T3) +Stage 4 (T6) |
| `~/.claude/workflows/phase5-review.js` | MODIFY | Read diff/contents from input, fallback to disk |
| `~/.claude/workflows/phase6-verify.js` | MODIFY | mandatoryNextAction, totalIterations, max 10 guard |
| `skills/detecting-environment/SKILL.md` | MODIFY | +Step 0 state validation, +Workflow call for Steps 5-7 |
| `skills/designing-solutions/SKILL.md` | MODIFY | +Step 0 state validation, +progress anchors |
| `skills/planning-implementation/SKILL.md` | MODIFY | +Step 0 entry guard (skip-design), +Workflow call Steps 2-4 |
| `skills/implementing-changes/SKILL.md` | MODIFY | +Step 0, +Step 4b compensation loop, updated output contract |
| `skills/reviewing-implementation/SKILL.md` | MODIFY | +Step 0 state validation, read diff/contents from Phase 4 |
| `skills/verifying-completion/SKILL.md` | MODIFY | +Step 0, simplified loop (mechanical mandatoryNextAction) |
| `skills/finishing-development/SKILL.md` | MODIFY | +Step 0 state validation |
| `skills/project-workflow-claude/SKILL.md` | MODIFY | v2.8, Workflow Scripts table, Global Rule #7, state init |
| `skills/project-workflow-claude/references/transition-rules.md` | MODIFY | skip-design escape hatch documentation |
| `.claude/state/project-workflow-state.json` | MODIFY | +escapeHatchesUsed field (default []) |
| `install.sh` | MODIFY | Install 2 new workflow scripts |

## 5. Verification

### Per-Task Verification

| Task | Verification Commands |
|------|----------------------|
| T1 | `node -c ~/.claude/workflows/phase1-detect-knowledge.js` (syntax), `grep -c 'Bash\|Read\|Write' ~/.claude/workflows/phase1-detect-knowledge.js` should return 0 (no file I/O) |
| T2 | `node -c ~/.claude/workflows/phase2-plan-generate.js`, `grep -c 'Bash\|Read\|Write' ~/.claude/workflows/phase2-plan-generate.js` should return 0 |
| T3 | `grep 'diffText' ~/.claude/workflows/phase4-implement.js` returns matches, `grep 'constructDiff.*diffText' ~/.claude/workflows/phase5-review.js` returns match |
| T4 | `grep -l 'Step 0.*State Validation' skills/*/SKILL.md \| wc -l` should be >= 7, `grep 'skip design' skills/planning-implementation/SKILL.md` returns match |
| T5 | `grep 'mandatoryNextAction' ~/.claude/workflows/phase6-verify.js` returns >= 3 matches |
| T6 | `grep 'Completion Guarantee' ~/.claude/workflows/phase4-implement.js` returns match, `grep 'compensation loop' skills/implementing-changes/SKILL.md` returns match |
| T7 | `grep 'v2.8' skills/project-workflow-claude/SKILL.md` returns match, `grep 'phase1-detect-knowledge' install.sh` returns match |

### Integration Verification

| Check | Command |
|-------|---------|
| Syntax | `node -c ~/.claude/workflows/phase*.js` (all 6 scripts) |
| Lint | `git diff --check` (no whitespace errors) |
| SKILL.md YAML | `head -15 skills/*/SKILL.md \| grep -c '^---'` (frontmatter present) |
| Existing test | `bash tests/test-strategic-thinking.sh` (must still pass) |
| File count | `ls ~/.claude/workflows/phase*.js \| wc -l` should be 6 (was 4) |
| State init | New state file includes `escapeHatchesUsed`, `version: "v2.8"` |

## 6. Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| New workflows break existing flow | Low | Additive; existing phase3/4/5/6 call sites unchanged |
| Phase 5 misses context without disk reads | Medium | Fallback to disk read if diffText/fileContents missing from input |
| Phase 4 retry wastes tokens | Medium | 3 max retries, targets only incomplete tasks, 50k advisory cap |
| Skip-design guard too aggressive | Low | Blocks only when BOTH spec AND grill null AND no escape hatch |
| T3+T6 both modify phase4-implement.js → merge conflict | Medium | Implement in order: T3 first, T6 second (T6 adds Stage 4 after T3's Stage 3 changes) |
| Existing state.json lacks new fields | Low | `escapeHatchesUsed` defaults to `[]` when absent; version mismatch causes fresh init |
| File contents snapshot too large (>50k tokens) | Medium | Truncate file contents to 300 lines each in snapshot; full content available on disk |
| Partial deployment (6 scripts, old state) | Low | `install.sh` is atomic per script; state file is runtime-initialized |

## 7. Task Dependency Graph

```
T1 (phase1-detect-knowledge.js + state-validation.md)
 ├──> T4 depends on state-validation.md
 │
T2 (phase2-plan-generate.js) — independent
 │
T3 (context dedup: phase4-implement.js + phase5-review.js)
 ├──> T6 also modifies phase4-implement.js → do T3 first, then T6
 │
T4 (state validation: 7 skills) — depends on T1 (state-validation.md)
 │
T5 (phase6 loop contract) — independent
 │
T6 (phase4 completion guarantee) — depends on T3 (same file: phase4-implement.js)
 │
T7 (orchestrator + install) — independent, last (registers all scripts)
```

## 8. json:tasks

```json:tasks
[
  {
    "id": "T1-create-detect-knowledge-workflow",
    "prompt": "Create two new files:\n\n## File 1: ~/.claude/workflows/phase1-detect-knowledge.js\n\nA Workflow script for detecting-environment Steps 5-7. It orchestrates agent() calls only — NO Bash, NO Read, NO Write, NO file I/O.\n\nStructure:\n```js\nexport const meta = {\n  name: 'phase1-detect-knowledge',\n  description: 'Orchestrate knowledge analysis + skill selection + context summary for detecting-environment Steps 5-7',\n  phases: [\n    {title: 'Analyze', detail: 'Parallel: codebase architecture + skill inventory analysis'},\n    {title: 'Select', detail: 'Skill selection from codebase/task signals'},\n    {title: 'Synthesize', detail: 'Aggregate into contextSummary + loadedSkills'}\n  ]\n}\n\nvar input = typeof args === 'string' ? JSON.parse(args) : args\nvar projectType = input.projectType || 'unknown'\nvar commitSha = input.commitSha || ''\nvar branchName = input.branchName || ''\nvar contextMdExists = !!input.contextMdExists\nvar knowledgeMdExists = !!input.knowledgeMdExists\nvar claudeMdExists = !!input.claudeMdExists\nvar allFresh = !!input.allFresh\n\nphase('Analyze')\nvar analysisResults = await parallel([\n  function() {\n    return agent(\n      'Analyze the codebase architecture for a ' + projectType + ' project.\\n' +\n      'Identify: key modules, dependency graph, error handling patterns, testing conventions, middleware/interceptor chain.\\n' +\n      'Context artifacts fresh: ' + allFresh + '. If stale, note what analysis is needed.\\n' +\n      'Return structured findings.',\n      {label: 'analyze-architecture', model: 'sonnet'}\n    )\n  },\n  function() {\n    return agent(\n      'Analyze the skill inventory for a skills repository.\\n' +\n      'Identify: skill categories and counts, key cross-cutting skills, workflow scripts installed, reference docs available.\\n' +\n      'Return structured findings.',\n      {label: 'analyze-skills', model: 'haiku'}\n    )\n  }\n])\n\nvar archFindings = analysisResults[0] || ''\nvar skillFindings = analysisResults[1] || ''\n\nphase('Select')\nvar skillSelection = await agent(\n  'Select skills to load based on codebase signals and task signals.\\n\\n' +\n  '=== CODEBASE ANALYSIS ===\\n' + archFindings + '\\n\\n' +\n  '=== SKILL INVENTORY ===\\n' + skillFindings + '\\n\\n' +\n  'Project type: ' + projectType + '\\n' +\n  'Return: {selectedSkills: string[], reasoning: string}',\n  {label: 'select-skills', model: 'haiku', schema: {\n    type: 'object',\n    required: ['selectedSkills', 'reasoning'],\n    properties: {\n      selectedSkills: {type: 'array', items: {type: 'string'}},\n      reasoning: {type: 'string'}\n    }\n  }}\n)\n\nphase('Synthesize')\nvar contextSummary = {\n  projectType: projectType,\n  commitSha: commitSha,\n  contextMdStatus: contextMdExists ? (allFresh ? 'fresh' : 'stale') : 'missing',\n  knowledgeMdStatus: knowledgeMdExists ? (allFresh ? 'fresh' : 'stale') : 'missing',\n  loadedSkills: skillSelection ? skillSelection.selectedSkills : [],\n  contextWarnings: []\n}\n\nif (!allFresh) contextSummary.contextWarnings.push('Context artifacts stale — refresh recommended')\nif (!contextMdExists) contextSummary.contextWarnings.push('CONTEXT.md missing')\nif (!knowledgeMdExists) contextSummary.contextWarnings.push('knowledge.md missing')\n\nreturn {\n  contextSummary: contextSummary,\n  loadedSkills: skillSelection ? skillSelection.selectedSkills : [],\n  contextWarnings: contextSummary.contextWarnings\n}\n```\n\n## File 2: skills/project-workflow-claude/references/state-validation.md\n\nDocument required state fields for each phase:\n\n| Phase (Skill) | Required Fields | Optional Fields | Blocking Condition |\n|---------------|----------------|-----------------|-------------------|\n| detecting-environment | taskIntakePath | — | None (first phase) |\n| designing-solutions | contextSummaryPath | — | None |\n| planning-implementation | contextSummaryPath | specPath, grillEvidencePath | BOTH specPath AND grillEvidencePath null AND \"skip design\" NOT in escapeHatchesUsed |\n| implementing-changes | planPath | — | None |\n| reviewing-implementation | quickGateResultsPath | — | None |\n| verifying-completion | reviewResultsPath | — | None |\n| finishing-development | verificationResultsPath | — | None |\n\n### Skip-Design Escape Hatch\n\nWhen user says \"skip design\":\n1. Record \"skip design\" in state.json `escapeHatchesUsed` array\n2. planning-implementation Step 0 allows null specPath + grillEvidencePath\n3. planning-implementation uses task-intake.json as sole requirements source\n4. Plan document MUST include note: \"⚠️ Design Phase Skipped — requirements from task-intake.json only\"\n\n### Backward Compatibility\n- `escapeHatchesUsed` defaults to `[]` when missing from state file\n- State files from v2.7 (missing new fields) are auto-upgraded on first load",
    "files": [
      "~/.claude/workflows/phase1-detect-knowledge.js",
      "skills/project-workflow-claude/references/state-validation.md"
    ],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": ["phase3-consensus.js pattern", "workflow-state-contract.md"],
    "intakeRefs": ["approvedInScope", "constraints"],
    "grillRefs": ["A1-designing-solutions-workflow"],
    "expectedEvidence": [
      "~/.claude/workflows/phase1-detect-knowledge.js exists and parses (node -c)",
      "grep -c 'Bash\\|Read\\|Write' phase1-detect-knowledge.js returns 0",
      "skills/project-workflow-claude/references/state-validation.md exists with per-phase table"
    ],
    "forbiddenEvidence": [
      "no Bash(), Read(), Write() calls in phase1-detect-knowledge.js"
    ],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T2-create-plan-generate-workflow",
    "prompt": "Create ~/.claude/workflows/phase2-plan-generate.js — a Workflow script for planning-implementation Steps 2-4.\n\nWhat it does (in-memory, no file I/O):\n1. Generates plan content with json:tasks block (1 agent)\n2. Validates task schema PROGRAMMATICALLY (zero agent calls — pure JS validation)\n3. Enriches context for consensus review (1 agent)\n\nWhat it does NOT do:\n- Does NOT read specs from disk (specContent passed as input)\n- Does NOT write .claude/plans/ files (SKILL.md does that)\n- Does NOT run Bash or Read tools\n\nStructure:\n```js\nexport const meta = {\n  name: 'phase2-plan-generate',\n  description: 'Generate plan with json:tasks, validate schema, enrich context for consensus review',\n  phases: [\n    {title: 'Generate', detail: 'Agent generates plan with json:tasks block'},\n    {title: 'Validate', detail: 'Programmatic task schema validation'},\n    {title: 'Enrich', detail: 'Collect context for consensus review'}\n  ]\n}\n\nvar input = typeof args === 'string' ? JSON.parse(args) : args\nvar specContent = input.specContent || ''\nvar specPath = input.specPath || ''\nvar contextSummary = input.contextSummary || {}\nvar grillSummary = input.grillSummary || {}\nvar taskIntake = input.taskIntake || {}\n\nphase('Generate')\nvar planResult = await agent(\n  'Write an implementation plan for the following spec.\\n\\n' +\n  '=== SPEC ===\\n' + specContent + '\\n\\n' +\n  '=== CONTEXT ===\\n' + JSON.stringify(contextSummary, null, 2) + '\\n\\n' +\n  '=== GRILL DECISIONS ===\\n' + JSON.stringify(grillSummary, null, 2) + '\\n\\n' +\n  '=== TASK INTAKE ===\\n' + JSON.stringify(taskIntake, null, 2) + '\\n\\n' +\n  'The plan MUST include a ```json:tasks fenced code block at the end with an array of task objects.\\n' +\n  'Each task needs: id (T<number>-<name>), prompt, files, complexity, mutatesFiles, expectedEvidence, forbiddenEvidence, patchBackStrategy.\\n' +\n  'Return: {planContent: string, tasks: array}',\n  {\n    label: 'generate-plan',\n    model: 'sonnet',\n    schema: {\n      type: 'object',\n      required: ['planContent', 'tasks'],\n      properties: {\n        planContent: {type: 'string'},\n        tasks: {type: 'array', items: {\n          type: 'object',\n          required: ['id', 'prompt', 'files', 'complexity', 'mutatesFiles'],\n          properties: {\n            id: {type: 'string'},\n            prompt: {type: 'string'},\n            files: {type: 'array', items: {type: 'string'}},\n            complexity: {type: 'string', enum: ['simple', 'medium', 'complex']},\n            mutatesFiles: {type: 'boolean'},\n            expectedEvidence: {type: 'array', items: {type: 'string'}},\n            forbiddenEvidence: {type: 'array', items: {type: 'string'}},\n            patchBackStrategy: {type: 'string', enum: ['no-isolation', 'harness-managed', 'external-report']}\n          }\n        }}\n      }\n    }\n  }\n)\n\nphase('Validate')\n// PROGRAMMATIC validation — no agent calls\nvar tasks = planResult.tasks || []\nvar validationErrors = []\nfor (var i = 0; i < tasks.length; i++) {\n  var t = tasks[i]\n  if (!t.id || !t.id.match(/^T\\d+-/)) {\n    validationErrors.push('Task ' + i + ': id must match T<number>-<name>')\n  }\n  if (!t.prompt || t.prompt.length < 10) {\n    validationErrors.push((t.id || 'task ' + i) + ': prompt too short or missing')\n  }\n  if (!t.files || t.files.length === 0) {\n    validationErrors.push((t.id || 'task ' + i) + ': files array missing or empty')\n  }\n  if (['simple', 'medium', 'complex'].indexOf(t.complexity) === -1) {\n    validationErrors.push((t.id || 'task ' + i) + ': invalid complexity: ' + t.complexity)\n  }\n  if (t.mutatesFiles) {\n    if (!t.patchBackStrategy) {\n      validationErrors.push((t.id || 'task ' + i) + ': mutating task missing patchBackStrategy')\n    } else if (['no-isolation', 'harness-managed', 'external-report'].indexOf(t.patchBackStrategy) === -1) {\n      validationErrors.push((t.id || 'task ' + i) + ': invalid patchBackStrategy: ' + t.patchBackStrategy)\n    }\n  }\n  if (!t.expectedEvidence || t.expectedEvidence.length === 0) {\n    var hasVerification = t.prompt && /\\b(verify|test|confirm|check|validate)\\b/i.test(t.prompt)\n    if (!hasVerification) {\n      validationErrors.push((t.id || 'task ' + i) + ': missing expectedEvidence with no verification in prompt')\n    }\n  }\n}\n\nphase('Enrich')\nvar enriched = await agent(\n  'Prepare context for consensus review.\\n\\n' +\n  '=== PLAN CONTENT ===\\n' + (planResult.planContent || '').substring(0, 8000) + '\\n\\n' +\n  '=== CONTEXT SUMMARY ===\\n' + JSON.stringify(contextSummary, null, 2) + '\\n\\n' +\n  '=== GRILL SUMMARY ===\\n' + JSON.stringify(grillSummary, null, 2) + '\\n\\n' +\n  '=== TASK INTAKE ===\\n' + JSON.stringify(taskIntake, null, 2) + '\\n\\n' +\n  'Return: {enrichedContext: object, scopeWarnings: string[]}',\n  {label: 'enrich-context', model: 'haiku', schema: {\n    type: 'object',\n    required: ['enrichedContext'],\n    properties: {\n      enrichedContext: {type: 'object'},\n      scopeWarnings: {type: 'array', items: {type: 'string'}}\n    }\n  }}\n)\n\nreturn {\n  planContent: planResult.planContent,\n  tasks: tasks,\n  validationErrors: validationErrors,\n  enrichedContext: enriched ? enriched.enrichedContext : {},\n  scopeWarnings: enriched ? (enriched.scopeWarnings || []) : []\n}\n```",
    "files": [
      "~/.claude/workflows/phase2-plan-generate.js"
    ],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": ["phase3-consensus.js pattern", "task-schema.md"],
    "intakeRefs": ["approvedInScope", "constraints"],
    "grillRefs": [],
    "expectedEvidence": [
      "~/.claude/workflows/phase2-plan-generate.js exists and parses (node -c)",
      "grep -c 'Bash\\|Read\\|Write' phase2-plan-generate.js returns 0",
      "Programmatic task validation (no agent) for id, prompt, files, complexity, patchBackStrategy"
    ],
    "forbiddenEvidence": [
      "no Bash(), Read(), Write() in script",
      "no agent calls in Validate phase"
    ],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T3-context-dedup-phase4-phase5",
    "prompt": "Add diffText and fileContentsSnapshot to Phase 4 output so Phase 5 can consume them without disk re-reads.\n\nIMPORTANT: phase5-review.js ALREADY reads task.diffText first (L340) and task.fileContents first (L219). Zero changes to phase5-review.js. Only modify phase4-implement.js.\n\n## Modify ~/.claude/workflows/phase4-implement.js\n\n1. In Stage 1 (Implement), extend the implementer schema to include `diffText`:\n```js\nschema: {\n  type: 'object',\n  properties: {\n    changedFiles: {type: 'array', items: {type: 'string'}},\n    diffText: {type: 'string'},  // NEW: per-task git diff\n    fileContentsSnapshot: {type: 'object'},  // NEW: {filePath: content} post-implementation\n    expectedEvidenceObserved: {type: 'array', items: {type: 'string'}},\n    forbiddenEvidenceObserved: {type: 'array', items: {type: 'string'}},\n    summary: {type: 'string'}\n  }\n}\n```\n\n2. After pipeline results, collect from implementer output:\n```js\n// In Stage 1 promise chain, after setting taskChangedFiles:\ntaskChangedFiles[task.id] = (implResult && implResult.changedFiles) ? implResult.changedFiles : []\ntaskDiffs[task.id] = (implResult && implResult.diffText) ? implResult.diffText : ''\ntaskFileSnapshots[task.id] = (implResult && implResult.fileContentsSnapshot) ? implResult.fileContentsSnapshot : {}\n```\n\n3. Add to final return object:\n```js\nreturn {\n  total: tasks.length,\n  passed: passed,\n  failed: failed,\n  selfReviewStatus: selfReviewStatus,\n  perTaskDiffs: taskDiffs,              // NEW: {taskId: diffText}\n  fileContentsSnapshots: taskFileSnapshots  // NEW: {taskId: {file: content}}\n}\n```\n\n4. The implementer prompt should ask the agent to include diffText in its response. Add to buildImplementerPrompt: `'\\nAfter implementation, run `git diff` and include the output as diffText in your response.'`\n\n## Zero changes to phase5-review.js\n\n- L340: `constructDiff(task)` already returns `task.diffText || 'DIFF NOT AVAILABLE...'`\n- L219-233: `enrichTaskForReview(task)` already loops over `task.fileContents` first\n- Phase 5 already consumes these fields if present — Phase 4 just wasn't providing them",
    "files": [
      "~/.claude/workflows/phase4-implement.js"
    ],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": ["phase4-implement.js current structure", "phase5-review.js current structure"],
    "intakeRefs": ["constraints"],
    "grillRefs": ["A4-context-duplication"],
    "expectedEvidence": [
      "phase4-implement.js output includes perTaskDiffs and fileContentsSnapshots",
      "phase5-review.js constructDiff reads from task.diffText first with fallback",
      "phase5-review.js enrichTaskForReview reads from task.fileContents first with fallback",
      "All existing fallback paths still work"
    ],
    "forbiddenEvidence": [
      "no removal of fallback paths",
      "no change to review logic (only context source)"
    ],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T4-state-validation-boundaries",
    "prompt": "Add Step 0 state validation to all 7 execution skills + orchestrator + transition-rules + state.json.\n\nRead the reference file skills/project-workflow-claude/references/state-validation.md (created in T1) for the required fields table.\n\n## For EACH of these 7 files, insert a Step 0 section BEFORE the existing Step 1:\n\n1. skills/detecting-environment/SKILL.md\n2. skills/designing-solutions/SKILL.md\n3. skills/planning-implementation/SKILL.md\n4. skills/implementing-changes/SKILL.md\n5. skills/reviewing-implementation/SKILL.md\n6. skills/verifying-completion/SKILL.md\n7. skills/finishing-development/SKILL.md\n\nStep 0 pattern (insert as first procedure step after '## Procedure'):\n```\n### Step 0: State Validation\n\nRead `.claude/state/project-workflow-state.json`.\n\nVerify required fields per `skills/project-workflow-claude/references/state-validation.md`.\n\n**Required for this phase:** <list from state-validation.md>\n\n- If any required field is missing or null: BLOCK. Report exactly what's missing.\n- If `escapeHatchesUsed` is missing from state file: default to `[]` (backward compat).\n- If all required fields present: continue to Step 1.\n\n<phase-specific guard if applicable>\n```\n\nPhase-specific guards:\n- **designing-solutions**: No additional guard beyond contextSummaryPath.\n- **planning-implementation**: After checking contextSummaryPath, check: if BOTH specPath AND grillEvidencePath are null AND \"skip design\" NOT in escapeHatchesUsed → BLOCK with: \"No design spec found. Run /designing-solutions first, or say 'skip design' to proceed with task-intake.json only.\"\n- **implementing-changes**: No additional guard beyond planPath.\n- **reviewing-implementation**: No additional guard beyond quickGateResultsPath.\n- **verifying-completion**: No additional guard beyond reviewResultsPath.\n- **finishing-development**: No additional guard beyond verificationResultsPath.\n- **detecting-environment**: Only requires taskIntakePath. No additional guard.\n\n## Additional changes to designing-solutions/SKILL.md\n\nAfter each procedure step, add a progress anchor on its own line:\n```\n[Step N/9] <step-name> — <one-line result>\n```\n\n## Changes to skills/project-workflow-claude/SKILL.md\n\n1. In Reference Documents table, add row:\n```\n| `state-validation.md` | Per-phase required fields, skip-design logic, backward compatibility |\n```\n\n2. In Global Rules, add as rule 7:\n```\n7. **Task Completion Guarantee** — Phase 4 retries incomplete tasks before handoff. All tasks must be DONE or explicitly STUCK with reasons.\n```\n\n3. In Start or Resume Step 2 (Initialize state), update version to \"v2.8\" and add `\"escapeHatchesUsed\": []` to the state JSON template.\n\n## Changes to skills/project-workflow-claude/references/transition-rules.md\n\nUnder Escape Hatches, add after existing entries:\n```\n- `skip design`: route to `planning-implementation` with task-intake.json as sole requirements source. Records \"skip design\" in state `escapeHatchesUsed`. Plan gets ⚠️ Design Phase Skipped annotation.\n```\n\n## Changes to .claude/state/project-workflow-state.json\n\nIn the current state file, add `\"escapeHatchesUsed\": []` to the JSON. Keep all existing fields.\n\n## IMPORTANT\n- Read each skill file BEFORE editing it\n- Insert Step 0 as the FIRST step after '## Procedure'\n- Do NOT change any other content in the skill files\n- Match existing indentation and formatting style of each file",
    "files": [
      "skills/detecting-environment/SKILL.md",
      "skills/designing-solutions/SKILL.md",
      "skills/planning-implementation/SKILL.md",
      "skills/implementing-changes/SKILL.md",
      "skills/reviewing-implementation/SKILL.md",
      "skills/verifying-completion/SKILL.md",
      "skills/finishing-development/SKILL.md",
      "skills/project-workflow-claude/SKILL.md",
      "skills/project-workflow-claude/references/transition-rules.md",
      ".claude/state/project-workflow-state.json"
    ],
    "complexity": "complex",
    "mutatesFiles": true,
    "contextRefs": ["state-validation.md (T1)", "transition-rules.md", "workflow-state-contract.md"],
    "intakeRefs": ["approvedInScope", "constraints"],
    "grillRefs": ["S1-design-interactive"],
    "expectedEvidence": [
      "grep -l 'Step 0.*State Validation' skills/*/SKILL.md | wc -l >= 7",
      "grep 'skip design' skills/planning-implementation/SKILL.md returns match",
      "grep 'escapeHatchesUsed' skills/project-workflow-claude/SKILL.md returns match",
      "grep 'v2.8' skills/project-workflow-claude/SKILL.md returns match",
      "state.json has escapeHatchesUsed field",
      "transition-rules.md has skip-design entry"
    ],
    "forbiddenEvidence": [
      "no removal of existing procedure steps",
      "no blocking when required fields are present"
    ],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T5-phase6-loop-contract",
    "prompt": "Strengthen the Phase 6 loop contract in phase6-verify.js and verifying-completion/SKILL.md.\n\n## Modify ~/.claude/workflows/phase6-verify.js\n\n1. Parse new input fields: `totalIterations` (cumulative count from master).\n2. Add `mandatoryNextAction` to ALL return paths. Possible values:\n   - `\"RE_RUN_CHECKS\"`: Fixes applied. Master MUST re-run Bash checks and re-invoke.\n   - `\"DONE\"`: All passed OR max iterations exhausted. Master MUST exit loop.\n3. Add `verdict` field: `\"PASSED\" | \"EXHAUSTED\" | \"IN_PROGRESS\"`.\n4. Keep existing `dryRounds` logic (2 consecutive clean rounds → DONE).\n5. New guard: if totalIterations >= 10 and NOT all passed → `mandatoryNextAction = \"DONE\"`, `verdict = \"EXHAUSTED\"`. Return remaining failures.\n6. Keep ALL existing functionality: failure analysis, fix pipeline, evidence checks, quickGate audit, grillEvidence.\n\nReturn shape (all paths):\n```js\n{\n  allPassed: boolean,\n  dryRounds: number,\n  totalIterations: number,\n  mandatoryNextAction: \"RE_RUN_CHECKS\" | \"DONE\",\n  verdict: \"PASSED\" | \"EXHAUSTED\" | \"IN_PROGRESS\",\n  remainingFailures: string[],\n  evidenceFailures: [...],\n  phase: \"verify-passed\" | \"fix-complete\" | \"exhausted\",\n  quickGateAudit: boolean | string,\n  grillEvidenceAvailable: boolean\n}\n```\n\n## Modify skills/verifying-completion/SKILL.md\n\nUpdate Step 4 to use the mechanical loop:\n```\n### Step 4: Verification Loop (mechanical)\n\n1. Initialize loop counter: `iterations = 0`.\n2. Run all check commands: `go build ./...`, `go test ./...`, `go vet ./...`, `golangci-lint run ./...`.\n3. Compute evidence checks (file existence, text presence/absence).\n4. Call `Workflow(name='phase6-verify', args={checkResults, evidenceChecks, dryRounds, totalIterations: iterations})`.\n5. Read `mandatoryNextAction` from result:\n   - `\"RE_RUN_CHECKS\"`: increment iterations, go to step 2.\n   - `\"DONE\"`: proceed to Step 5 (report).\n6. Stop condition: if iterations >= 10, force exit even if mandatoryNextAction says RE_RUN_CHECKS.\n```\n\n## IMPORTANT\n- Read current phase6-verify.js fully before editing\n- Keep all existing fix pipeline and evidence check logic\n- Only add fields and guards — don't remove existing functionality\n- The master agent re-runs Bash (this is correct — Workflow can't Bash)",
    "files": [
      "~/.claude/workflows/phase6-verify.js",
      "skills/verifying-completion/SKILL.md"
    ],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": ["phase6-verify.js current structure"],
    "intakeRefs": ["constraints"],
    "grillRefs": ["A3-phase6-loop-control"],
    "expectedEvidence": [
      "grep 'mandatoryNextAction' ~/.claude/workflows/phase6-verify.js | wc -l >= 3",
      "grep 'totalIterations' ~/.claude/workflows/phase6-verify.js returns match",
      "grep 'EXHAUSTED' ~/.claude/workflows/phase6-verify.js returns match",
      "verifying-completion SKILL.md Step 4 has mechanical RE_RUN_CHECKS/DONE loop",
      "All existing fix/evidence logic preserved"
    ],
    "forbiddenEvidence": [
      "no Bash/Read calls in phase6-verify.js",
      "no removal of existing failure analysis logic"
    ],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T6-phase4-completion-guarantee",
    "prompt": "Add Stage 4 Completion Guarantee to phase4-implement.js and compensation loop to implementing-changes/SKILL.md.\n\n⚠️ T3 also modifies phase4-implement.js. T6 must be applied AFTER T3's changes. Read the current state of the file BEFORE editing — it may already have T3's diffText/fileContentsSnapshot changes.\n\n## Modify ~/.claude/workflows/phase4-implement.js (new Stage 4)\n\nAfter Stage 3 self-review (the pipeline() call), add:\n\n```js\n// ===== Stage 4: Completion Guarantee =====\nphase('Completion Guarantee')\n\nvar MAX_RETRY_ROUNDS = 3\nvar incompleteTasks = results.filter(function(r) {\n  return r && r.status !== 'DONE' && r.status !== 'DONE_WITH_CONCERNS'\n})\n\nvar retryRound = 0\nwhile (incompleteTasks.length > 0 && retryRound < MAX_RETRY_ROUNDS) {\n  retryRound++\n  log('Retry round ' + retryRound + ': ' + incompleteTasks.length + ' tasks incomplete')\n\n  // Retry incomplete tasks with simpler pipeline (implement + quick-verify only)\n  var retryResults = await pipeline(incompleteTasks,\n    function(task) {\n      var retryPrompt = 'RETRY attempt ' + retryRound + ' for task ' + task.id + '.\\n' +\n        'Previous attempt was incomplete. Try a DIFFERENT approach.\\n\\n' +\n        'ORIGINAL TASK:\\n' + task.prompt + '\\n\\n' +\n        'If stuck, simplify to the minimum viable change. Return changedFiles and summary.'\n      return agent(retryPrompt, {\n        label: 'retry-' + task.id + '-r' + retryRound,\n        model: 'sonnet',\n        isolation: getIsolation(task),\n        schema: {\n          type: 'object',\n          properties: {\n            changedFiles: {type: 'array', items: {type: 'string'}},\n            summary: {type: 'string'}\n          }\n        }\n      })\n    },\n    function(result, task) {\n      if (!result) return {taskId: task.id, status: 'STUCK', stuckReason: 'Retry agent returned null'}\n      return agent('Quick verify retry for ' + task.id, {\n        label: 'retry-verify-' + task.id,\n        schema: {\n          type: 'object',\n          properties: {buildPassed: {type: 'boolean'}, errors: {type: 'array', items: {type: 'string'}}}\n        }\n      }).then(function(vr) {\n        if (!vr || !vr.buildPassed) {\n          return {taskId: task.id, status: 'STUCK', stuckReason: 'Retry verification failed: ' + JSON.stringify(vr ? vr.errors : [])}\n        }\n        return {taskId: task.id, status: 'DONE', changedFiles: result.changedFiles || [], _retryRound: retryRound}\n      })\n    }\n  )\n\n  // Merge successful retries back into results\n  var stillIncomplete = []\n  for (var i = 0; i < retryResults.length; i++) {\n    var rr = retryResults[i]\n    if (rr && rr.status === 'DONE') {\n      for (var j = 0; j < results.length; j++) {\n        if (results[j] && results[j].taskId === rr.taskId) {\n          results[j].status = 'DONE'\n          results[j]._retryRound = retryRound\n          if (rr.changedFiles) results[j].changedFiles = rr.changedFiles\n          break\n        }\n      }\n    } else {\n      stillIncomplete.push({taskId: (rr ? rr.taskId : 'unknown'), status: 'STUCK', stuckReason: (rr ? rr.stuckReason : 'unknown')})\n    }\n  }\n  incompleteTasks = stillIncomplete\n}\n\n// Mark final incomplete as STUCK with detailed reason\nif (incompleteTasks.length > 0) {\n  log(incompleteTasks.length + ' tasks STUCK after ' + MAX_RETRY_ROUNDS + ' retries')\n}\nvar stuckTasks = incompleteTasks.map(function(t) {\n  return {taskId: t.taskId || 'unknown', status: 'STUCK', stuckReason: t.stuckReason || ('Failed after ' + retryRound + ' retries')}\n})\n\n// Add stuck tasks to selfReviewStatus for Phase 5 visibility\nfor (var k = 0; k < stuckTasks.length; k++) {\n  selfReviewStatus.push(stuckTasks[k])\n}\n```\n\nKey design decisions:\n- Only retries tasks with status NOT in ['DONE', 'DONE_WITH_CONCERNS']\n- Retry uses simpler pipeline: implement + quick-verify only (no self-review)\n- Per-task retry, NOT whole-pipeline abort\n- Max 3 retry rounds regardless of token budget\n- 50k token budget is advisory (logged but not enforced in JS — Workflow scripts can't track tokens precisely)\n\n## Modify skills/implementing-changes/SKILL.md\n\nAfter Step 4 (Execute Workflow Script), add Step 4b:\n```\n### Step 4b: Completion Guarantee (Compensation Loop)\n\nIf the Workflow result contains STUCK tasks (status === 'STUCK'):\n\n1. Log stuckCount and stuckReasons for user visibility.\n2. If stuckReason includes 'NEEDS_CONTEXT':\n   - Enrich the stuck tasks: re-read their target files, resolve missing grill decisions.\n   - Build a new enriched tasks array with ONLY the stuck tasks.\n   - Re-invoke `Workflow(name='phase4-implement', args={tasks: enrichedStuckTasks})`.\n   - Max 2 compensation loops.\n3. If stuckReason includes 'BLOCKED' or after 2 compensation loops exhausted:\n   - Report to user: which tasks are stuck, why, and what manual action is needed.\n4. All DONE and DONE_WITH_CONCERNS tasks proceed normally to Step 5 (Worktree Review).\n```",
    "files": [
      "~/.claude/workflows/phase4-implement.js",
      "skills/implementing-changes/SKILL.md"
    ],
    "complexity": "complex",
    "mutatesFiles": true,
    "contextRefs": ["phase4-implement.js current structure (may have T3 changes)"],
    "intakeRefs": ["constraints"],
    "grillRefs": [],
    "expectedEvidence": [
      "grep 'Completion Guarantee' ~/.claude/workflows/phase4-implement.js returns match",
      "grep 'MAX_RETRY_ROUNDS = 3' ~/.claude/workflows/phase4-implement.js returns match",
      "grep 'STUCK' ~/.claude/workflows/phase4-implement.js returns >= 2 matches",
      "Retry targets only tasks with status NOT DONE/DONE_WITH_CONCERNS",
      "Compensation loop in implementing-changes SKILL.md (max 2)"
    ],
    "forbiddenEvidence": [
      "no infinite loop (MAX_RETRY_ROUNDS hardcoded to 3)",
      "no re-running already-DONE tasks",
      "no whole-pipeline abort on single task failure"
    ],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T7-update-orchestrator-install",
    "prompt": "Update orchestrator SKILL.md to v2.8 and install.sh to register 6 workflow scripts.\n\n## Modify skills/project-workflow-claude/SKILL.md\n\n1. Header: `# Project Workflow Claude v2.8 — Modular Orchestrator`\n2. In 'Workflow Scripts' table, BEFORE the phase3-consensus row, add:\n```\n| `phase1-detect-knowledge` | Detect Steps 5-7: knowledge analysis + skill selection + context summary |\n| `phase2-plan-generate` | Plan Steps 2-4: generate plan + validate schema + enrich context |\n```\n3. In 'Start or Resume' Step 2 (Initialize state), update:\n   - Version: `\"v2.8\"`\n   - Add: `\"escapeHatchesUsed\": []` to the JSON template\n4. In 'Global Rules', add as rule 7:\n```\n7. **Task Completion Guarantee** — Phase 4 retries incomplete tasks (max 3 rounds internally + 2 compensation). All tasks must be DONE or explicitly STUCK with documented reasons before Phase 5 handoff.\n```\n5. In 'Reference Documents' table, add:\n```\n| `state-validation.md` | Per-phase required fields table, skip-design logic, backward compatibility |\n```\n\n## Modify install.sh\n\nRead install.sh first to understand the current pattern. Then add installation of the 2 new workflow scripts. If install.sh uses cp from a source directory:\n```bash\ncp \"$SKILL_DIR/project-workflow-claude/workflows/phase1-detect-knowledge.js\" \"$HOME/.claude/workflows/phase1-detect-knowledge.js\" 2>/dev/null || true\ncp \"$SKILL_DIR/project-workflow-claude/workflows/phase2-plan-generate.js\" \"$HOME/.claude/workflows/phase2-plan-generate.js\" 2>/dev/null || true\n```\n\nIf install.sh lists them differently (e.g., as a for loop), match the existing pattern.",
    "files": [
      "skills/project-workflow-claude/SKILL.md",
      "install.sh"
    ],
    "complexity": "simple",
    "mutatesFiles": true,
    "contextRefs": ["install.sh current pattern", "orchestrator SKILL.md current state"],
    "intakeRefs": ["approvedInScope"],
    "grillRefs": [],
    "expectedEvidence": [
      "grep 'v2.8' skills/project-workflow-claude/SKILL.md returns >= 2 matches",
      "grep 'phase1-detect-knowledge' skills/project-workflow-claude/SKILL.md returns match",
      "grep 'phase2-plan-generate' skills/project-workflow-claude/SKILL.md returns match",
      "grep 'phase1-detect-knowledge' install.sh returns match",
      "grep 'phase2-plan-generate' install.sh returns match",
      "grep 'escapeHatchesUsed' skills/project-workflow-claude/SKILL.md returns match"
    ],
    "forbiddenEvidence": [
      "no removal of existing phase3/4/5/6 workflow references",
      "no version hardcoded as v2.7 anywhere"
    ],
    "patchBackStrategy": "no-isolation"
  }
]
```

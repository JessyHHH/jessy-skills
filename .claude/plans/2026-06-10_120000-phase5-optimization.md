# Phase 5 Optimization: 39min to 8-14min -- Implementation Plan

## Goal
Reduce Phase 5 (Two-Stage Review) wall clock time from ~39min to ~8-14min while maintaining or improving review quality. Implement 6 optimizations (P0+P1+P2) discovered through analysis of session `36064b31` and research on superpowers/Claude Code workflow patterns.

## Context
- Skills Repository, commit `81e2b8d`
- Key files:
  - `~/.claude/workflows/phase5-review.js` (459 lines) -- the review orchestrator script
  - `skills/project-workflow-claude/SKILL.md` -- workflow documentation, Phase 5 section
- Session `36064b31` showed Phase 5 taking 39.1min with heavy file re-reading (task-02 read documents.go 12+ times) and parallel bottleneck (task-01 waited 1830s for task-02 spec review)
- Research sources: superpowers (obra/superpowers), Claude Code workflow docs, Qodo benchmark (Haiku 4.5 outperforms Sonnet 4.5 on code review)
- Current state: Phase 5 runs as a two-stage pipeline -- all tasks complete spec review before any code review starts. Agents freely explore files with no read limits. All reviews use Sonnet regardless of task complexity.

## Approach

### P0: Context Injection + Anti-Exploration Guardrails
- **buildSpecReviewPrompt()**: Inject pre-extracted `task.specSection` and `task.fileContents` directly into prompt. Agent no longer reads plan file.
- **Hard guardrails in every review prompt**: "Maximum 5 file reads. DO NOT read same file twice. FORBIDDEN: go build, go test, go vet, grep exploration. Maximum 3 thinking blocks."

### P0: Tiered Model Selection
- Spec Review: Haiku (checklist verification with injected context)
- Code Review Correctness: Sonnet (multi-file logic)
- Code Review Safety: Sonnet (security impact)
- Code Review Simplicity: Haiku (dead code/style checklist)
- Adversarial Verify: Haiku (already Haiku)
- Final Review: Haiku (summary synthesis)
- High-risk tasks (>=2 missing expectedEvidence from Quick Gate): upgrade spec review to Sonnet

### P1: Strongly Recommended Fast Gate
- If `fastGateResults` is null/undefined: log advisory warning. Guardrails still apply (read limits, no exploration, no build/test). Fast Gate provides the quickest checks but its absence is not blocking.
- New output field: `fastGateResultsAvailable: boolean` in return value.

### P1: Git-Diff-Based Code Review
- Code reviewers receive `git diff` output instead of file paths to explore. Only review changed lines.
- Master agent pre-computes diffs before Phase 5:
  ```
  Master agent pre-computes:
    for each task:
      task.diffText = "git diff <base>..<head> -- " + task.files.join(' ')
    
    The diffContent is injected as task.diffText in workflow args.
    Script receives pre-computed diff text — no shelling out required.
    Backward compatible: if task.diffText is absent, falls back to file-based review.
  ```

### P2: Per-Task Independent Pipeline
- Main flow: `pipeline(tasks, enrichStage, reviewStage)`
- `enrichStage(task)`: no-op — returns enriched task data (already enriched by Master)
- `reviewStage(task)`: performs spec review → code review → adversarial verify for a single task
  - Stages within reviewStage are sequential per-task (spec → code → adversarial)
  - Tasks flow independently through pipeline — reviewStage for task-01 runs concurrently with enrichStage for task-03
  - Wall clock ≈ max(single task spec+code+adversarial time) + overhead

## Files

### 1. `~/.claude/workflows/phase5-review.js` -- Full refactor

Key structural changes:

**New functions:**
- `enrichTaskForReview(task, planText, grillEvidence)` -- builds the injected context for each task from plan sections, grill decisions, file contents
- `buildGuardedSpecPrompt(task)` -- constructs spec review prompt with injected context + guardrails + model=haiku (or sonnet for high-risk)
- `buildGuardedCodePrompt(task, reviewType, diff)` -- constructs code review prompt with git diff + guardrails + layered models (correctness=sonnet, safety=sonnet, simplicity=haiku)
- `buildFullReviewStage(task)` -- orchestrates spec→code→adversarial for a single task, returns complete review result
- `computeTaskRisk(task, quickGateResults)` -- determines if task is high-risk based on quickGateResults

**Fast Gate guard at script entry:**
```javascript
if (!fastGateResults) {
  // P1: Strongly Recommended Fast Gate — advisory warning, not blocking
  log('ADVISORY: fastGateResults not provided. Fast Gate checks (git diff --stat, git diff --check, import check, files-exist) are strongly recommended before Phase 5. Continuing with guardrails only.')
  // Guardrails still apply (read limits, no exploration, no build/test)
  // Fast Gate provides the quickest checks but its absence is not blocking
}
```

**New input fields accepted:**
- `task.specSection` -- pre-extracted plan section relevant to this task's spec
- `task.fileContents` -- full file contents array (same as Phase 4 enrichment)
- `task.grillDecisions` -- resolved grill decisions (same as Phase 4 enrichment)
- `task.baseSha` -- base commit SHA for git diff construction (used by Master agent, not script)
- `task.headSha` -- head commit SHA for git diff construction (used by Master agent, not script)
- `task.diffText` -- pre-computed git diff text (Master agent injects this; script uses it directly)
- `quickGateResults.perTask` -- per-task quick gate results for risk computation

**Main flow: `pipeline(tasks, enrichStage, reviewStage)`**
- `enrichStage(task)`: no-op — returns enriched task data (already enriched by Master)
- `reviewStage(task)`: performs spec review → code review → adversarial verify for a single task
  - Stages within reviewStage are sequential per-task (spec → code → adversarial)
  - Tasks flow independently through pipeline — reviewStage for task-01 runs concurrently with enrichStage for task-03
  - Wall clock ≈ max(single task spec+code+adversarial time) + overhead

**Main pipeline change:**
```javascript
// OLD: two-stage pipeline, all tasks complete spec before any code review
var specResults = await pipeline(tasks,
  function(task) { /* spec review */ },
  function(specResult, task) { /* code review */ }
)

// NEW: per-task independent pipeline
var results = await pipeline(tasks,
  function(task) { return task },  // enrichStage: no-op (already enriched by Master)
  function(task) {
    // Full review for this one task: spec → code → adversarial
    return buildFullReviewStage(task)
  }
)
```

**Guardrail suffix injected into every review prompt:**
```
REVIEW GUARDRAILS (HARD):
- Maximum 5 file reads total across this review. DO NOT read any file more than once.
- FORBIDDEN commands: go build, go test, go vet, golangci-lint, grep, find. You are a reviewer, not a builder.
- Maximum 3 thinking blocks. Make your assessment and commit to it.
- If you need context beyond what is provided in this prompt, flag it as a finding rather than exploring.
```

### 2. `skills/project-workflow-claude/SKILL.md` -- Phase 5 section update

Update to reflect:
- New per-task pipeline model (each task flows independently)
- Context injection requirement (Master must pre-extract spec sections)
- Strongly Recommended Fast Gate (advisory warning, not blocking)
- Tiered model selection table (which model for which review type)
- Git-diff-based code review mode
- Anti-exploration guardrails documented
- Update version to v2.6 (both frontmatter `version` field and heading)

**Model selection table to add:**
| Review Stage | Model | Rationale |
|-------------|-------|-----------|
| Spec Review | Haiku (default) / Sonnet (high-risk) | Checklist verification with injected context; Haiku handles matching well |
| Code Review: Correctness | Sonnet | Multi-file logic analysis requires deeper reasoning |
| Code Review: Safety | Sonnet | Security impact analysis requires depth |
| Code Review: Simplicity | Haiku | Dead code/style checklist is pattern-matching |
| Adversarial Verify | Haiku | Already Haiku; binary refute/confirm decisions |
| Final Review | Haiku | Summary synthesis of already-reviewed findings |

**Fast Gate section update:**
Master agent should run bash checks BEFORE Phase 5 (Strongly Recommended, not blocking):
```bash
git diff --stat          # confirm expected files changed
git diff --check         # whitespace errors
# import check, files-exist check
```
Build `fastGateResults` object. Phase 5 script logs advisory warning if missing — guardrails still apply but absence is non-blocking.
New output field: `fastGateResultsAvailable: boolean` in return value.

## Verification
- `node -c ~/.claude/workflows/phase5-review.js` exits 0
- `git diff --check` clean
- Skill YAML frontmatter check: `head -15 skills/project-workflow-claude/SKILL.md`
- Manual review: verify guardrails text appears in all review prompt builder functions
- Backward compatibility: old task objects (without new optional fields) still work via fallback paths
- Pipeline independence: verify that task-01 result does not depend on task-02 completion
- Pipeline smoke test: create a test script with 2 mock tasks, verify pipeline(enrichStage, reviewStage) produces independent results
- Verify guardrails text appears in every agent prompt

## Risks
- **Low**: Backward compatible -- new task fields all optional, old invocations fall back gracefully. Fast Gate is Strongly Recommended but not blocking -- existing callers without fastGateResults continue to work with advisory warning.
- **Low**: Haiku for spec review may miss complex issues -- mitigated by Quick Gate high-risk upgrade path (tasks with >=2 missing expectedEvidence get Sonnet spec review).
- **Low**: Haiku for final review may miss cross-task consistency issues -- mitigated by the fact that each task is independently verified first, and the final review is a synthesis step of already-gathered findings. Only skipped when tasks <= 1 or no shared files.
- **Medium**: Per-task pipeline may not serialize correctly if tasks share files — Concrete mitigation: Before launching the workflow, Master agent checks for file overlap across tasks. If two tasks share files in `task.files`: log warning "tasks X and Y share files — may see stale review content". If shared files are in `mutatesFiles=true` tasks: serialize those tasks sequentially. The enrichment step documents overlap in `task._sharedFilesWarning`.
- **Medium**: Git-diff-based code review may miss context needed to understand correctness -- mitigated by also injecting full file contents via `task.fileContents` (already enriched by Phase 4 enrichment step). The diff focuses attention, the full files provide context.

## Tasks

```json:tasks
[
  {
    "id": "task-01",
    "prompt": "## Task: Full refactor of phase5-review.js with P0+P1+P2 optimizations\n\nEdit the file `/home/huangzexi/.claude/workflows/phase5-review.js`. Replace its entire content with the refactored version described below.\n\n### Architecture Change: Two-Stage Pipeline → Per-Task Independent Pipeline\n\nThe current script uses a two-stage pipeline where ALL tasks complete spec review before ANY code review starts. The new structure makes each task flow independently through its full review pipeline.\n\n**OLD structure:**\n```javascript\nvar specResults = await pipeline(tasks,\n  function(task) { /* spec review for this task */ },\n  function(specResult, task) { /* code review only if spec passes */ }\n)\n// Then collect findings, then adversarial verification, then final review\n```\n\n**NEW structure:**\n```javascript\nvar results = await pipeline(tasks,\n  function(task) { return task },  // enrichStage: no-op (already enriched by Master)\n  function(task) {\n    return buildFullReviewStage(task)  // spec → code → adversarial, all for THIS task only\n  }\n)\n// Then collect findings, then final review (unchanged)\n```\n\n### New Functions to Add\n\n#### 1. `enrichTaskForReview(task, planText, grillEvidence)`\nBuilds the injected context for each task. Reads from `task.specSection`, `task.fileContents`, `task.grillDecisions`. Returns a prompt string with sections:\n- `## Task Specification` (from task.specSection or extracts from planText by matching task.id and task.files)\n- `## Current Code` (from task.fileContents, same format as Phase 4 enrichment)\n- `## Design Decisions` (from task.grillDecisions, same format as Phase 4 enrichment)\n\nIf `task.specSection` is not provided, fall back to extracting relevant sections from `planText` by searching for lines that mention `task.id` or any file in `task.files`.\n\n#### 2. `computeTaskRisk(task, quickGateResults)`\nReturns `'high'` or `'normal'`. High risk when `quickGateResults.perTask[task.id]` has `expectedPassed` with >=2 missing items OR `forbiddenClean` is false. Otherwise normal risk.\n\n#### 3. `buildGuardedSpecPrompt(task)`\nConstructs the spec review prompt with injected context, guardrails, and tiered model selection.\n\n**Model**: `task.riskLevel === 'high'` ? `'sonnet'` : `'haiku'`\n\n**Prompt structure:**\n```\nSpec compliance review for task TASK_ID.\nDO NOT read any plan files. All context is provided below.\n\n## Task Specification\n[injected spec section from enrichTaskForReview]\n\n## Current Code\n[injected file contents from enrichTaskForReview, or list of file paths if not provided]\n\n## Design Decisions\n[injected grill decisions from enrichTaskForReview, or \"None provided\" if absent]\n\n## Instructions\nCheck: does the implementation match the task spec exactly? Nothing extra? Nothing missing?\nVerify against expectedEvidence: [list task.expectedEvidence]\nCheck for forbiddenEvidence: [list task.forbiddenEvidence]\nReturn APPROVE, ITERATE, or REJECT with specific issues.\n\nREVIEW GUARDRAILS (HARD):\n- Maximum 5 file reads total across this review. DO NOT read any file more than once.\n- FORBIDDEN commands: go build, go test, go vet, golangci-lint, grep, find. You are a reviewer, not a builder.\n- Maximum 3 thinking blocks. Make your assessment and commit to it.\n- If you need context beyond what is provided in this prompt, flag it as a finding rather than exploring.\n```\n\nUse `SPEC_SCHEMA` for the response schema (already defined in the file).\n\n#### 4. `buildGuardedCodePrompt(task, reviewType, diff)`\nConstructs the code review prompt with git diff + guardrails + layered models.\n\n**Models by reviewType:**\n- `'correctness'` → `'sonnet'`\n- `'safety'` → `'sonnet'`\n- `'simplicity'` → `'haiku'`\n\n**Prompt structure:**\n```\nReview REVIEW_TYPE for task TASK_ID.\n\n## Git Diff (ONLY review these changed lines)\n` + diff + `\n\n## Full File Contents (for context, do not review unchanged lines)\n[injected file contents from task.fileContents, each file wrapped in code block]\n\n## Instructions\n- CORRECTNESS: Logic errors, edge cases, error handling, concurrency safety.\n- SAFETY: Nil/null panics, resource leaks, security, data races.\n- SIMPLICITY: Over-engineering, dead code, style, Karpathy compliance.\nFlag findings with severity CRITICAL/HIGH/MEDIUM/LOW.\n\nREVIEW GUARDRAILS (HARD):\n- Maximum 5 file reads total across this review. DO NOT read any file more than once.\n- FORBIDDEN commands: go build, go test, go vet, golangci-lint, grep, find. You are a reviewer, not a builder.\n- Maximum 3 thinking blocks. Make your assessment and commit to it.\n- Only review the CHANGED lines shown in the git diff. Full files are provided for context only.\n```\n\nUse `REVIEW_SCHEMA` for the response schema (already defined in the file).\n\n#### 5. `buildFullReviewStage(task)`\nOrchestrates the complete review for a single task. Returns the task result object.\n\n**Logic:**\n```javascript\nfunction buildFullReviewStage(task) {\n  var taskResult = {taskId: task.id, specVerdict: null, findings: [], stage: 'spec'}\n\n  // Step 1: Fast Gate check (skip if already done globally, but validate per-task)\n  if (fastGateIssues.length > 0) {\n    taskResult.stage = 'fast-gate-failed'\n    return taskResult\n  }\n\n  // Step 2: Spec Review (gated by complexity)\n  if (shouldSkipSpecReview(task)) {\n    taskResult.specVerdict = 'APPROVE'\n    taskResult.stage = 'spec-skipped'\n  } else {\n    var specPrompt = buildGuardedSpecPrompt(task)  // returns {prompt, model}
    var specResult = await agent(specPrompt.prompt, {
      label: 'spec-' + task.id,
      schema: SPEC_SCHEMA,
      model: specPrompt.model
    })\n    taskResult.specVerdict = specResult.verdict\n    if (specResult.verdict === 'REJECT' || specResult.verdict === 'ITERATE') {\n      specFailed.push({taskId: task.id, issues: specResult.issues, verdict: specResult.verdict})\n      return taskResult  // stop here, don't proceed to code review\n    }\n  }\n\n  // Step 3: Code Review (only if spec approves, gated by complexity)\n  if (shouldSkipCodeReview(task)) {\n    taskResult.stage = 'code-skipped'\n  } else {\n    var diff = constructDiff(task)  // build git diff string from baseSha/headSha + task.files\n    var codeDepth = getCodeReviewDepth(task)\n\n    if (codeDepth === 'correctness-only') {\n      var corrPrompt = buildGuardedCodePrompt(task, 'correctness', diff)  // returns {prompt, model}
      var corrResult = await agent(corrPrompt.prompt, {
        label: 'correctness-' + task.id,
        schema: REVIEW_SCHEMA,
        model: corrPrompt.model
      })\n      if (corrResult && corrResult.findings) {\n        corrResult.findings.forEach(function(f) { f.taskId = task.id; f.reviewType = 'correctness' })\n        taskResult.findings = taskResult.findings.concat(corrResult.findings)\n      }\n    } else if (codeDepth === 'full') {\n      // Parallel: correctness (sonnet) + safety (sonnet) + simplicity (haiku)\n      var codeResults = await parallel([\n        function() {\n          var p = buildGuardedCodePrompt(task, 'correctness', diff)\n          return agent(p.prompt, {label: 'correctness-' + task.id, schema: REVIEW_SCHEMA, model: p.model})\n        },\n        function() {\n          var p = buildGuardedCodePrompt(task, 'safety', diff)\n          return agent(p.prompt, {label: 'safety-' + task.id, schema: REVIEW_SCHEMA, model: p.model})\n        },\n        function() {\n          var p = buildGuardedCodePrompt(task, 'simplicity', diff)\n          return agent(p.prompt, {label: 'simplicity-' + task.id, schema: REVIEW_SCHEMA, model: p.model})\n        }\n      ])n      for (var j = 0; j < codeResults.length; j++) {\n        if (codeResults[j] && codeResults[j].findings) {\n          var reviewType = ['correctness', 'safety', 'simplicity'][j]\n          codeResults[j].findings.forEach(function(f) { f.taskId = task.id; f.reviewType = reviewType })\n          taskResult.findings = taskResult.findings.concat(codeResults[j].findings)\n        }\n      }\n    }\n    taskResult.stage = 'code-done'\n  }\n\n  // Step 4: Adversarial Verify for CRITICAL findings in this task (inline, not deferred)\n  var taskCritical = taskResult.findings.filter(function(f) { return f.severity === 'CRITICAL' })\n  if (taskCritical.length > 0) {\n    for (var k = 0; k < taskCritical.length; k++) {\n      var f = taskCritical[k]\n      // Complexity-gated: complex gets 3 skeptics, medium gets 1, simple auto-confirm\n      if (shouldSkipAdversarial(task)) {\n        if (getComplexity(task) === 'medium') {\n          var vote = await agent(\n            'Try to REFUTE this finding. Default to refuted=false if uncertain.\\n\\nFinding: ' + f.description + '\\nFile: ' + f.file + (f.line ? ' (line ' + f.line + ')' : ''),\n            {label: 'skeptic-' + k + '-' + f.file, schema: SKEPTIC_SCHEMA, model: 'haiku'}\n          )\n          if (vote && vote.refuted) { f.severity = 'HIGH' }\n          else { verifiedCritical.push(f) }\n        } else {\n          verifiedCritical.push(f)\n        }\n        continue\n      }\n      // Complex: 3 skeptics in parallel\n      var votes = await parallel([\n        function() { return agent('Try to REFUTE...', {label: 'skeptic-1-' + f.file, schema: SKEPTIC_SCHEMA, model: 'haiku'}) },\n        function() { return agent('Try to REFUTE...', {label: 'skeptic-2-' + f.file, schema: SKEPTIC_SCHEMA, model: 'haiku'}) },\n        function() { return agent('Try to REFUTE...', {label: 'skeptic-3-' + f.file, schema: SKEPTIC_SCHEMA, model: 'haiku'}) }\n      ])\n      var validVotes = votes.filter(Boolean)\n      if (validVotes.length < 2) {\n        verifiedCritical.push({finding: f, verified: 'UNVERIFIED', reason: 'Only ' + validVotes.length + ' of 3 skeptics responded'})\n      } else {\n        var survived = validVotes.filter(function(v) { return !v.refuted }).length >= 2\n        if (survived) { verifiedCritical.push(f) }\n        else { f.severity = 'HIGH' }\n      }\n    }\n  }\n\n  return taskResult\n}\n```\n\n#### 6. `constructDiff(task)`\nReturns the pre-computed git diff string for the task's files. Master agent pre-computes diffs before Phase 5 and injects them as `task.diffText`. No shelling out required.\n\n```javascript\nfunction constructDiff(task) {\n  // Master agent pre-computes: task.diffText = "git diff <base>..<head> -- " + task.files.join(' ')\n  // The diffContent is injected as task.diffText in workflow args.\n  // Script receives pre-computed diff text — no shelling out required.\n  // Backward compatible: if task.diffText is absent, falls back to file-based review.\n  return task.diffText || 'DIFF NOT AVAILABLE — review full file contents instead.'\n}\n```\n\n### Changes to Existing Code\n\n#### Fast Gate: Strongly Recommended (lines 24-38)\nReplace the current soft-skip behavior with advisory enforcement:\n```javascript\nvar fastGateResults = input.fastGateResults || null\n\n// P1: Strongly Recommended Fast Gate — advisory warning continues, not blocking\nif (!fastGateResults) {\n  log('ADVISORY: fastGateResults not provided. Fast Gate checks (git diff --stat, git diff --check, import check, files-exist) are strongly recommended before Phase 5. Continuing with guardrails only.')\n  // Guardrails still apply (read limits, no exploration, no build/test)\n  // Fast Gate provides the quickest checks but its absence is not blocking\n}\nvar fastGateResultsAvailable = !!fastGateResults  // new output field\n```\n\n#### Pipeline call (lines 167-248)\nReplace the two-stage pipeline with per-task pipeline:\n```javascript\n// Enrich tasks with context before pipeline\nfor (var i = 0; i < tasks.length; i++) {\n  tasks[i].riskLevel = computeTaskRisk(tasks[i], fastGateResults)\n  tasks[i].enrichedContext = enrichTaskForReview(tasks[i], planText, grillEvidence)\n}\n\n// Per-Task Independent Pipeline (P2) — two-stage form: enrichStage + reviewStage\nvar results = await pipeline(tasks,\n  function(task) { return task },  // enrichStage: no-op (already enriched by Master)\n  function(task) {\n    return buildFullReviewStage(task)\n  }\n)\n```\n\n#### Final Review model (line ~353)\nChange final review model from `'sonnet'` to `'haiku'`:\n```javascript\n{ schema: { ... }, model: 'haiku' }\n```\n\n#### Input parsing (lines 12-24)\nAdd new optional fields to input parsing:\n```javascript\nvar planText = input.planText || ''\nvar grillEvidence = input.grillEvidence || null\nvar baseSha = input.baseSha || ''\nvar headSha = input.headSha || ''\n```\n\nEach task now also accepts:\n- `task.specSection` (string, optional)\n- `task.diffText` (string, optional — pre-computed git diff for this task's files, injected by Master agent)\n- `task.fileContents` (array, optional — same format as Phase 4 enrichment)\n- `task.grillDecisions` (array, optional — same format as Phase 4 enrichment)\n\n### Important Coding Rules\n- Match existing code style: 2-space indent, `var` declarations, `//` comments, function declarations (not arrow for top-level)\n- Arrow functions for callbacks are OK (already used in the file)\n- Use `Array.isArray()` for array checks\n- Template literals are OK (already used)\n- Keep all existing schemas (REVIEW_SCHEMA, SPEC_SCHEMA, SKEPTIC_SCHEMA) unchanged\n- Keep existing helper functions: `getComplexity`, `shouldSkipSpecReview`, `shouldSkipCodeReview`, `getCodeReviewDepth`, `shouldSkipAdversarial`, `shouldSkipFinalReview`\n- Keep the `meta` export at the top unchanged\n- Keep the final return object structure (layersApplied, layersSkipped, fastGateIssues, estimatedTokensSaved, stage, passed, findings, criticalCount, highCount, mediumCount, lowCount, specFailed, finalReview, finalVerdict, finalBlockedBy)\n- Forward compatibility: all new task fields are optional, fall back gracefully when absent",
    "files": ["/home/huangzexi/.claude/workflows/phase5-review.js"],
    "complexity": "complex",
    "mutatesFiles": true,
    "contextRefs": [],
    "intakeRefs": [],
    "grillRefs": ["A1", "A2", "A3", "S1", "S2", "S3"],
    "expectedEvidence": [
      "node -c ~/.claude/workflows/phase5-review.js exits 0",
      "Fast Gate logs advisory warning when fastGateResults is null/undefined (not blocking, uses log() not console.warn)",
      "buildGuardedSpecPrompt returns {prompt, model} — haiku for normal-risk tasks, sonnet for high-risk",
      "buildGuardedSpecPrompt uses sonnet model for high-risk tasks (>=2 missing expectedEvidence)",
      "buildGuardedCodePrompt returns {prompt, model} — sonnet for correctness/safety, haiku for simplicity",
      "buildFullReviewStage orchestrates spec→code→adversarial for a single task",
      "Per-task pipeline: task-01 can reach adversarial while task-02 is still in spec review",
      "Guardrails text appears in all review prompts: 'Maximum 5 file reads', 'FORBIDDEN commands', 'Maximum 3 thinking blocks'",
      "Final review uses haiku model (was sonnet)",
      "Backward compatible: tasks without new optional fields still work",
      "constructDiff returns fallback message when task.diffText is not provided"
    ],
    "forbiddenEvidence": [
      "no two-stage pipeline (specResults = await pipeline(tasks, specStage, codeStage))",
      "no mandatory blocking for fastGateResults missing",
      "no sonnet model for simplicity review",
      "no sonnet model for final review",
      "no removal of existing schemas (REVIEW_SCHEMA, SPEC_SCHEMA, SKEPTIC_SCHEMA)",
      "no removal of existing helper functions",
      "no ES6+ features that break node -c (let, const outside function scope, destructuring in function params)",
      "no console.warn() calls (use log() instead)",
      "no buildGuardedSpecPrompt() calling agent() internally",
      "no buildGuardedCodePrompt() calling agent() internally"
    ],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "task-02",
    "prompt": "## Task: Update SKILL.md Phase 5 section for v2.6 optimizations\n\nEdit the file `/home/huangzexi/personal/jessy-skills/skills/project-workflow-claude/SKILL.md`.\n\n### Changes\n\n#### 1. Update version to v2.6\n- **Line 4 (YAML frontmatter):** Change `version: \"v2.5\"` to `version: \"v2.6\"`\n- **Line 20 (heading):** Change `# Project Workflow Claude v2.5` to `# Project Workflow Claude v2.6`\n\n#### 2. Replace Phase 5 section (lines 650-709)\n\nReplace the ENTIRE Phase 5 section (from `## Phase 5: Two-Stage Review` through the Red Flags block) with the following updated content.\n\n**New content for Phase 5:**\n\n```markdown\n## Phase 5: Two-Stage Review (ALWAYS RUNS)\n\n**Goal:** Spec compliance review first → code quality review second. NEVER reverse order. Uses deterministic Workflow script with per-task independent pipeline, tiered model selection, context injection, and anti-exploration guardrails.\n\n### Review Layers (P1 Optimization)\n\nPhase 5 uses a 5-layer review model with tiered models to minimize wall clock time and token consumption. Complexity from Phase 2 task schema drives gating.\n\n| Layer | Name | Gates | Model | Agent Calls |\n|-------|------|-------|-------|-------------|\n| Layer 1 | Fast Gate (Strongly Recommended) | Master bash checks (files exist, git diff --stat, git diff --check, import check) — MUST run BEFORE phase5-review.js script. Script logs advisory warning if missing. | N/A (bash) | 0 agent calls |\n| Layer 2 | Spec Review | Gated by complexity: `simple` skips, `medium`/`complex` runs. Context injected directly — agent does NOT read plan file. | Haiku (default) / Sonnet (high-risk: >=2 missing expectedEvidence from Quick Gate) | 0-1 agent per task |\n| Layer 3 | Code Review | Gated by complexity: `simple` skips entirely, `medium` gets correctness-only (1 agent), `complex` gets full 3-agent parallel. Reviewers receive `git diff` output — only review changed lines. | Correctness: Sonnet, Safety: Sonnet, Simplicity: Haiku | 0-3 agents per task |\n| Layer 4 | Adversarial Verify | Gated by complexity: `simple` auto-confirms, `medium` gets 1 skeptic, `complex` gets 3 skeptics. Runs per-task inline (not deferred). | Haiku | 0-3 agents per CRITICAL finding |\n| Layer 5 | Final Review | Conditional: skip when <2 tasks OR no shared files. Synthesis of already-reviewed findings. | Haiku | 0-1 agent |\n\n**Anti-Exploration Guardrails (injected into every review prompt):**\n```\nMaximum 5 file reads. DO NOT read same file twice.\nFORBIDDEN: go build, go test, go vet, grep exploration.\nMaximum 3 thinking blocks.\n```\n\n**Expected wall clock: ~8-14min** (down from ~39min). **Token savings: ~60-70%** vs. uniform full Sonnet review.\n\n**Procedure:**\n\n1. **ANNOUNCE:** \"**Phase 5: Two-Stage Review** — per-task independent pipeline via phase5-review.js.\"\n\n2. **PREPARE (Master Agent):**\n   - Run bash checks → build `fastGateResults` (Strongly Recommended — script logs advisory warning if missing):\n     ```bash\n     git diff --stat          # confirm expected files changed\n     git diff --check         # whitespace errors\n     # import check, files-exist check per task\n     ```\n   - `Bash(command='git diff --name-only')` → changedFiles\n   - Re-read plan from `.claude/plans/` → planPath + planText\n   - Collect `selfReviewStatuses` from Phase 4 output\n   - Collect `quickGateResults` from Phase 4.6 output (per-task expectedEvidence/forbiddenEvidence results)\n   - For each task, pre-extract spec sections from plan and compute `git diff` per task files (using `baseSha`/`headSha` or HEAD~1/HEAD)\n\n3. **EXECUTE:**\n   ```\n   Workflow(\n     name='phase5-review',\n     args={\n       planPath, planText, changedFiles,\n       tasks: [...enriched tasks with specSection, diff, fileContents, grillDecisions, baseSha, headSha],\n       selfReviewStatuses: [...],\n       fastGateResults: {...},\n       quickGateResults: {...},\n       grillEvidence: {...}\n     }\n   )\n   ```\n   The script uses **per-task independent pipeline**:\n   - Each task flows independently through spec → code → adversarial\n   - Task A can complete full review while Task B is still in spec review\n   - Wall clock = max(single task full review time), not sum of all stages\n   - **Spec Review**: Context injected directly (task.specSection, task.fileContents, task.grillDecisions). Haiku by default, Sonnet for high-risk tasks.\n   - **Code Review**: Reviewers receive `git diff` output — only review changed lines. Full file contents provided for context only. Tiered models (correctness=Sonnet, safety=Sonnet, simplicity=Haiku).\n   - **Adversarial Verification**: Runs per-task inline with findings. Complexity-gated: complex=3 skeptics, medium=1, simple=auto-confirm. All skeptics use Haiku.\n   - **Final Review**: Haiku synthesis of all per-task findings. Cross-task consistency. Skipped when <=1 task or no shared files.\n\n4. **FIX-AND-RETRY:**\n   - Read output → `{criticalCount, highCount, findings, specFailed, finalVerdict}`\n   - If `criticalCount > 0`: Agent fixes CRITICAL issues → re-run Workflow. Max 3 iterations.\n   - If `specFailed.length > 0`: Address spec gaps → fix implementation or update plan → re-run.\n   - Report to user on 3rd failure.\n\n5. **REPORT** → auto-transition to Phase 6:\n   ```\n   \"Phase 5: Reviewed\n   - Spec Compliance: [✓/✗]\n   - Code Quality: N findings (M CRITICAL, H HIGH)\n   → Phase 6.\"\n   ```\n\n**Red Flags (NEVER):**\n- Start code quality before spec compliance is ✅\n- Skip either stage\n- Accept \"close enough\"\n- Skip Fast Gate preparation (guardrails still apply but quality may degrade)\n- Use Sonnet for simplicity review or final review (Haiku is sufficient and faster)\n```\n\n#### 3. Update Phase 4.6 Quick Gate section (lines 627-648)\n\nAdd a note that `quickGateResults` must be passed to Phase 5 for risk computation:\n\nAfter the existing line \"Output: `quickGateResults = {passed, perTask: {taskId: {expectedPassed, forbiddenClean, filesMatch}}}`.\", add:\n\n```markdown\n\n   **IMPORTANT:** `quickGateResults` MUST be passed to Phase 5 as input. Phase 5 uses it to compute per-task risk level: tasks with >=2 missing expectedEvidence are classified as high-risk and receive Sonnet spec review (instead of Haiku).\n```\n\n#### 4. Update Phase 4 (lines 548-624) — add diff generation note\n\nIn Phase 4, step 3c (\"Extract plan sections\"), add a sub-step for diff generation:\n\nAfter the existing \"c. **Extract plan sections:**\" block, add:\n\n```markdown\n\n   c2. **Generate per-task git diff:** For each task, construct the git diff for its files:\n      ```bash\n      git diff <baseSha> <headSha> -- <task.files...>\n      ```\n      Store as `task.diff` (string). If baseSha/headSha not available, use `HEAD~1` and `HEAD`.\n      This diff is injected into Phase 5 code review prompts so reviewers only examine changed lines.\n```\n\n#### 5. Update self-driving transition table (line ~935)\n\nUpdate the Phase 4.6 → Phase 5 row:\n\nChange:\n```\n| 4.6 (Quick Gate) | 5 (Review) | Quick Gate ALL PASS |\n```\nTo:\n```\n| 4.6 (Quick Gate) | 5 (Review) | Quick Gate complete (fastGateResults + quickGateResults built) |\n```\n\nAlso update the Phase 4 → Phase 4.5 row if needed (the current row says \"All tasks done + Phase 4.5 worktree review complete\" — this should be fine as-is).\n\n### Important\n- Match existing markdown style (tables, code blocks, inline code, bold emphasis)\n- Preserve ALL content outside the changed sections\n- Do NOT change Phase 0, 0.3, 0.5, 1, 2, 3, 6, 7, 8 sections\n- The Phase 5 section is a COMPLETE REPLACEMENT from the `## Phase 5:` heading through the `---` separator before Phase 6\n- Test: the new Phase 5 section must contain the tiered model selection table with Haiku/Sonnet assignments\n- Test: the new Phase 5 section must mention \"per-task independent pipeline\"\n- Test: the new Phase 5 section must mention \"Mandatory Fast Gate\"\n- Test: the new Phase 5 section must mention \"Anti-Exploration Guardrails\"",
    "files": ["/home/huangzexi/personal/jessy-skills/skills/project-workflow-claude/SKILL.md"],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [],
    "intakeRefs": [],
    "grillRefs": ["A1", "A2", "A3", "S1", "S2", "S3"],
    "expectedEvidence": [
      "Version updated to v2.6 in YAML frontmatter (line 4)",
      "Version updated to v2.6 in main heading (line 20)",
      "Phase 5 section contains tiered model selection table (Haiku/Sonnet per review type)",
      "Phase 5 section mentions 'per-task independent pipeline'",
      "Phase 5 section mentions 'Mandatory Fast Gate' and 'logs advisory warning if missing'",
      "Phase 5 section mentions 'Anti-Exploration Guardrails' with max 5 reads, forbidden commands, max 3 thinking blocks",
      "Phase 5 section mentions 'Expected wall clock: ~8-14min'",
      "Phase 5 section mentions 'Context injected directly — agent does NOT read plan file'",
      "Phase 5 section mentions 'git diff output — only review changed lines'",
      "Phase 4.6 section has note about passing quickGateResults to Phase 5",
      "Phase 4 has diff generation sub-step (c2)",
      "Self-driving transition table updated for 4.6 → 5 row",
      "All other phases (0, 0.3, 0.5, 1, 2, 3, 6, 7, 8) unchanged"
    ],
    "forbiddenEvidence": [
      "no remaining references to v2.5 version",
      "no remaining 'pipeline(tasks, specStage, codeStage)' pattern in Phase 5 docs",
      "no remaining 'All tasks complete spec review before code review' language"
    ],
    "patchBackStrategy": "no-isolation"
  }
]
```

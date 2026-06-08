# Workflow Grill + Review Optimization Implementation Plan
> For agentic workers... implement only the approved design, keep changes surgical, preserve backward compatibility where specified, and produce fresh verification evidence before claiming completion.

## Goal

Close three quantified gaps in the `project-workflow-claude` self-driving pipeline: (P0) strengthen Phase 1 grill exit criteria with a mandatory hard checklist and requirement echo, (P1) reduce Phase 5 token consumption by 50-60% through complexity-gated layered review, (P2) add a Phase 4.6 Quick Gate between worktree merge and review, and (P3) persist grill decisions to `.claude/state/grill-evidence.json` for downstream audit cross-reference.

## Context

### Problem Summary (from Design Spec)

The design spec at `.claude/specs/2026-06-08-workflow-grill-review-optimization-design.md` documents three real-session failures:

1. **Session 85965f3f (mixclaw PRD):** Phase 1 self-check exit criteria allowed the model to skip deep requirements probing entirely — zero questions asked, Ambiguity Register never populated, Assumption Ledger never populated, and no requirement echo was performed. Root cause: prose-based exit criteria that the model self-grades without hard evidence.

2. **Session 09a23ec2 (blog monorepo):** Phase 5 made 50+ agent calls for a 7-task run (7 spec + 21 code quality + skeptics + final review), burning massive tokens and never completing. Root cause: uniform review depth regardless of task complexity — every task gets 3 parallel code quality agents plus adversarial verification.

3. **Architectural gap:** No validation exists between Phase 4.5 (worktree merge) and Phase 5 (review). Grill decisions exist only in conversation transcript with no file persistence for downstream phases.

### Approved Design Decisions

- P0: Replace Phase 1 prose exit criteria with a mandatory **Hard Grill Checklist** of 6 concrete items that MUST be printed with PASS/FAIL before exit. Add a **REQUIREMENT ECHO** step after EXPLORE (step 1.5) to catch scope drift early.
- P1: Add **layered review** to `phase5-review.js` with 4 layers: Fast Gate (master bash checks), Standard (complexity-gated spec review), Deep (complexity-gated code quality), and Final (conditional cross-task). Simple tasks skip code review entirely. Medium tasks get correctness-only (1 agent). Only complex tasks get full 3-agent parallel review.
- P2: Add **Phase 4.6 Quick Gate** as a master-agent phase between 4.5 and 5 — 4 deterministic checks (git diff, expectedEvidence grep, forbiddenEvidence grep, fail-fast) before entering expensive Phase 5 review.
- P3: Write **grill evidence** to `.claude/state/grill-evidence.json` after the Hard Grill Checklist passes, containing Ambiguity Register, Assumption Ledger, checklist results, requirement echo, scope statement, and success criteria.

### Scope Boundaries

**In scope:**
- `skills/project-workflow-claude/SKILL.md`: Phase 1 Hard Grill Checklist, REQUIREMENT ECHO, Phase 4.6 Quick Gate, grill-evidence.json documentation, Phase 5 layered review docs
- `.claude/workflows/phase5-review.js`: Layered review with complexity gating, fast gate input, skip optimizations
- `.claude/workflows/phase6-verify.js`: Accept Quick Gate evidence and grill evidence path for audit trail
- `tests/test-workflow-changes.sh`: New P0/P1/P2 test sections

**Out of scope:**
- Do NOT modify `phase3-consensus.js` or `phase4-implement.js`
- Do NOT modify other skills, `install.sh`, or user-global config
- Do NOT introduce new dependencies
- Do NOT change the Workflow tool invocation pattern
- `.claude/state/grill-evidence.json` is a runtime artifact — format documented in SKILL.md, no source file created

### Complexity Classification Rules

| Complexity | Criteria | Phase 5 Code Review |
|-----------|----------|---------------------|
| `simple` | Single file, no new interfaces, purely additive or purely subtractive | Skip entirely |
| `medium` | 2-3 files, or modifies existing interface, or has cross-file impact | Correctness only (1 agent) |
| `complex` | 4+ files, new public API, data model changes, concurrency, or security-sensitive | Full (3 agents) |

Missing complexity field defaults to `medium` (safe default).

## Approach

Implement in four tasks matching the approved design, keeping each edit traceable to a specific P0-P3 gap:

1. **T1 (SKILL.md):** Add Hard Grill Checklist (6 mandatory items with [ ] format) before PROPOSE. Add REQUIREMENT ECHO as step 1.5 after EXPLORE. Add Phase 4.6 Quick Gate section between Phase 4.5 and Phase 5 with the 5-step procedure. Document grill-evidence.json persistence and schema in Phase 1. Update Phase 5 section to describe the 4-layer review model. Update the self-driving transition table with Phase 4.6 row.

2. **T2 (phase5-review.js):** Add Layer 1 Fast Gate pre-computed results ingestion. Add complexity-gating functions (`shouldSkipSpecReview`, `getCodeReviewDepth`, `shouldSkipAdversarial`, `shouldSkipFinalReview`). Modify pipeline stages: gate spec review on complexity, gate code quality depth on complexity (0/1/3 agents), gate adversarial verification on complexity, gate final review on task count and file sharing. Add layer statistics to output. Preserve backward compatibility — if fast gate results not provided, skip Layer 1 with warning.

3. **T3 (phase6-verify.js):** Accept `quickGateEvidence` for audit trail. Accept `grillEvidencePath` for cross-reference. Both optional with backward compatibility warnings. No structural changes to existing evidence checking logic — these are additive inputs documented in output.

4. **T4 (tests):** Extend the existing test script with P0 checks (Hard Grill Checklist presence, 6 items, REQUIREMENT ECHO), P1 checks (complexity gating functions in phase5-review.js, skip logic), and P2 checks (Phase 4.6 Quick Gate in SKILL.md, grill-evidence.json in SKILL.md). Verify 70+ total checks pass.

## Files

Modify only these files:

- `skills/project-workflow-claude/SKILL.md` — P0 checklist, P0 requirement echo, P2 Phase 4.6, P3 grill-evidence.json docs, P1 layered review docs
- `.claude/workflows/phase5-review.js` — P1 layered review with complexity gating
- `.claude/workflows/phase6-verify.js` — P2 Quick Gate evidence, P3 grill evidence path
- `tests/test-workflow-changes.sh` — P0/P1/P2 test sections

Do NOT plan or make changes to:

- `.claude/workflows/phase3-consensus.js` — out of scope
- `.claude/workflows/phase4-implement.js` — out of scope
- Other skills or `install.sh`
- User global config (`/home/huangzexi/.claude/CLAUDE.md`)

## Verification

Required final verification commands after implementation:

- `bash tests/test-workflow-changes.sh`
- `git diff --check`

Expected final evidence:

- `skills/project-workflow-claude/SKILL.md` contains "HARD GRILL CHECKLIST" with 6 numbered [ ] items in Phase 1
- `skills/project-workflow-claude/SKILL.md` contains "REQUIREMENT ECHO" in Phase 1 between EXPLORE and GRILL
- `skills/project-workflow-claude/SKILL.md` contains "Phase 4.6" with Quick Gate procedure (5 steps)
- `skills/project-workflow-claude/SKILL.md` documents `.claude/state/grill-evidence.json` format and persistence in Phase 1
- `skills/project-workflow-claude/SKILL.md` Phase 5 section describes 4-layer review model with skip rules
- Self-driving transition table includes Phase 4.6 row
- `.claude/workflows/phase5-review.js` contains `shouldSkipSpecReview`, `getCodeReviewDepth`, `shouldSkipAdversarial`, `shouldSkipFinalReview` or equivalent complexity-gating logic
- `.claude/workflows/phase5-review.js` skips code quality review for `complexity='simple'` tasks
- `.claude/workflows/phase5-review.js` runs correctness-only (1 agent) for `complexity='medium'` tasks
- `.claude/workflows/phase5-review.js` runs full 3-agent parallel only for `complexity='complex'` tasks
- `.claude/workflows/phase5-review.js` accepts `fastGateResults` input with `filesExist`, `diffStat`, `diffCheck`, `importCheck`
- `.claude/workflows/phase5-review.js` reports `layersApplied`, `layersSkipped`, `estimatedTokensSaved` in output
- `.claude/workflows/phase6-verify.js` accepts `quickGateEvidence` and `grillEvidencePath` as optional inputs
- `.claude/workflows/phase6-verify.js` warns on missing optional inputs (backward compatibility)
- `tests/test-workflow-changes.sh` has P0/P1/P2 sections with Hard Grill Checklist, REQUIREMENT ECHO, layered review, Phase 4.6, and grill-evidence.json checks
- `tests/test-workflow-changes.sh` passes with 70+ total checks (previous ~53 + ~17 new)

Forbidden final evidence:

- Hard Grill Checklist has fewer or more than exactly 6 items
- Phase 5 runs code quality review for `complexity='simple'` tasks
- Phase 5 runs 3-agent parallel review for `complexity='medium'` tasks
- Phase 5 skips final review when >=2 tasks share files
- Phase 4.6 is implemented as a Workflow script (must be master-agent phase)
- `grill-evidence.json` is a committed source file (must be runtime-only)
- Phase 3 or Phase 4 scripts are modified
- Any new dependency is introduced
- Existing test checks are broken or weakened

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Simple tasks skip code review and miss bugs | Low | Phase 4 self-review + Phase 4.6 Quick Gate catch obvious issues; simple tasks are single-file and additive/subtractive |
| Hard Grill Checklist becomes rote checkboxing | Medium | Items 3 and 6 require substantive judgment, not mechanical checking; item 6 is explicitly self-grading ("Could someone implement from this spec without asking basic questions?") |
| Phase 4.6 adds latency (~5 bash commands) | Low | 5 bash commands < 2 seconds; Phase 5 saves 5-50+ agent calls, net latency reduction |
| Complexity misclassification in Phase 2 plans | Medium | Phase 3 consensus review checks task complexity; Phase 5 defaults to `medium` if field missing — safe behavior |
| Layered review skips needed cross-task checks | Low | `shouldSkipFinalReview` only skips when <2 tasks share files; shared files always trigger final review |
| Phase 5 output structure changes break Phase 6 consumption | Low | New fields added to output object, not removed; backward-compatible addition |

## Tasks

```json:tasks
[
  {
    "id": "T1",
    "prompt": "Update skills/project-workflow-claude/SKILL.md with P0 Hard Grill Checklist, P0 REQUIREMENT ECHO, P2 Phase 4.6 Quick Gate, P3 grill-evidence.json docs, and P1 layered review Phase 5 docs.\n\nCHANGES TO MAKE:\n\n1. **P0: REQUIREMENT ECHO** — In Phase 1, after EXPLORE (step 1) and before GRILL (step 2), insert new step 1.5:\n\n```\n1.5. REQUIREMENT ECHO:\n   After exploration, print a structured restatement of every requirement\n   extracted from:\n   - User's original message\n   - Task Intake Snapshot (Phase 0)\n   - Files read during EXPLORE\n   - Any relevant CONTEXT.md or knowledge.md facts\n\n   Format:\n     \"Requirements extracted:\n      1. [requirement] — source: [user message / intake snapshot / file X]\n      2. [requirement] — source: [user message / intake snapshot / file X]\n      ...\n\n      Complete and correct? (yes/no)\"\n\n   Ask the user: \"Complete and correct?\" before proceeding to the first\n   Grill question. If the user says no, update the requirements list.\n   If the user says yes, the echoed requirements become the authoritative\n   scope baseline for the rest of Phase 1.\n```\n\n2. **P0: HARD GRILL CHECKLIST** — Replace the current Phase 1 exit criteria prose (the 5 bullet points starting with \"Scope boundary is pinned\" through \"Success criteria include...\") with the mandatory checklist:\n\n```\n6. HARD GRILL CHECKLIST (mandatory printed output before exit):\n\n   The master agent MUST print this checklist with PASS/FAIL for each item.\n   If any item is FAIL, the Grill is NOT done. Re-open Ambiguity Register.\n\n   1. [ ] Ambiguity Register printed (minimum 3 items, or explain why <3)\n   2. [ ] Assumption Ledger printed (minimum 2 entries, or explain why <2)\n   3. [ ] Every \"open\" ambiguity addressed (asked user OR moved to \"assumed\" with ledger entry)\n   4. [ ] Success criteria are observable (specific commands + expected output)\n   5. [ ] Constraints documented (version, dep, compatibility)\n   6. [ ] Self-grade: \"Could someone implement from this spec without asking basic questions?\"\n          If no → grill NOT done. Re-open and probe.\n\n   ALL items MUST pass before proceeding to PROPOSE.\n```\n\n3. **P3: GRILL EVIDENCE PERSISTENCE** — After the Hard Grill Checklist, add documentation for writing grill evidence:\n\n```\n7. GRILL EVIDENCE PERSISTENCE:\n   After ALL checklist items pass and before writing the spec, write a\n   structured JSON file to .claude/state/grill-evidence.json:\n\n   {\n     \"timestamp\": \"<ISO 8601>\",\n     \"session\": \"<session-id>\",\n     \"ambiguityRegister\": [\n       {\n         \"id\": \"A1\",\n         \"question\": \"...\",\n         \"status\": \"answered|assumed|deferred-out-of-scope\",\n         \"impact\": \"...\",\n         \"recommendedAnswer\": \"...\",\n         \"decision\": \"...\"\n       }\n     ],\n     \"assumptionLedger\": [\n       {\n         \"id\": \"S1\",\n         \"assumption\": \"...\",\n         \"evidence\": \"...\",\n         \"confidence\": \"high|medium|low\",\n         \"correctionPath\": \"...\"\n       }\n     ],\n     \"checklistResults\": {\n       \"ambiguityRegisterPrinted\": true,\n       \"assumptionLedgerPrinted\": true,\n       \"openAmbiguitiesAddressed\": true,\n       \"successCriteriaObservable\": true,\n       \"constraintsDocumented\": true,\n       \"selfGrade\": \"PASS: spec is implementable without basic questions\"\n     },\n     \"requirementEcho\": [\"req1\", \"req2\", \"...\"],\n     \"scopeStatement\": \"...\",\n     \"successCriteria\": [\n       \"cmd: <specific command> exits 0\",\n       \"semantic: <observable behavior>\"\n     ]\n   }\n\n   Delegate writing to subagent (master agent does NOT write files).\n   Phase 4.6 reads this file to cross-reference evidence.\n   Phase 6 reads this file to validate semantic evidence.\n```\n\n4. **P2: PHASE 4.6 QUICK GATE** — Insert a new Phase 4.6 section between Phase 4.5 (Worktree Review) and Phase 5 (Two-Stage Review):\n\n```\n## Phase 4.6: Quick Gate (Master Agent)\n\n**Goal:** Validate that Phase 4 output matches expected evidence before entering\n          expensive Phase 5 review. Fail fast if evidence is missing.\n\n**Procedure:**\n\n1. git diff --stat:\n   Confirm expected files were changed. Compare against the task files\n   from the Phase 2 plan. Flag any missing or unexpected files.\n\n2. grep for expectedEvidence per task:\n   For each task with expectedEvidence entries, grep changed files for\n   the expected strings/patterns. Collect per-task results.\n\n3. grep for forbiddenEvidence per task:\n   For each task with forbiddenEvidence entries, grep changed files for\n   the forbidden strings/patterns. ANY match = FAIL.\n\n4. FAIL FAST:\n   - If expectedEvidence missing → report which task + which evidence\n   - If forbiddenEvidence found → report which task + which evidence\n   - If git diff shows unexpected files → report\n   - Return to Phase 4 to fix, OR proceed with documented concerns\n\n5. ALL PASS → auto-transition to Phase 5.\n\nInput: tasks array from Phase 2 plan (with expectedEvidence + forbiddenEvidence),\n       optional grill-evidence.json for cross-reference\nOutput: quickGateResults = {passed, perTask: {taskId: {expectedPassed, forbiddenClean, filesMatch}}}\n```\n\nAlso add Phase 4.6 to the Self-Driving Transition table:\n```\n| 4.5 (Worktree) | 4.6 (Quick Gate) | All worktree merges complete |\n| 4.6 (Quick Gate) | 5 (Review) | Quick Gate ALL PASS |\n```\n\n5. **P1: PHASE 5 LAYERED REVIEW DOCS** — Update the Phase 5 section to document the 4-layer review model. Replace the current Phase 5 procedure prose with documentation of:\n   - Layer 1 (Fast Gate): master bash checks (files exist, git diff --stat, git diff --check, import check) — runs BEFORE phase5-review.js\n   - Layer 2 (Standard): complexity-gated spec review — 'simple' skips, 'medium'/'complex' runs\n   - Layer 3 (Deep): complexity-gated code quality — 'simple' skips, 'medium' gets correctness-only (1 agent), 'complex' gets full (3 agents)\n   - Layer 4 (Final): conditional cross-task — skip when <2 tasks, skip when no shared files, run when >=2 tasks share files\n   - Skip rules for each layer\n   - Expected token savings (~50-60% for mixed-complexity runs)\n\n6. **STEP NUMBERING:** After inserting step 1.5 (REQUIREMENT ECHO) and replacing exit criteria with Hard Grill Checklist, ensure step numbering is consistent. Current steps are: 1. EXPLORE, 2. GRILL, 3. PROPOSE, 4. WRITE SPEC, 5. SELF-REVIEW, 6. SKILL RE-CHECK, 7. APPROVAL. After changes: 1. EXPLORE, 1.5. REQUIREMENT ECHO, 2. GRILL (Ambiguity Register + Assumption Ledger), 2a. Hard Grill Checklist, 2b. Grill Evidence Persistence, 3. PROPOSE, 4. WRITE SPEC, 5. SELF-REVIEW, 6. SKILL RE-CHECK, 7. APPROVAL.\n\nDo NOT modify any other files, workflow scripts, or skills.\n\nVerify with: grep -q 'HARD GRILL CHECKLIST' skills/project-workflow-claude/SKILL.md; grep -q 'REQUIREMENT ECHO' skills/project-workflow-claude/SKILL.md; grep -q 'Phase 4.6' skills/project-workflow-claude/SKILL.md; grep -q 'Quick Gate' skills/project-workflow-claude/SKILL.md; grep -q 'grill-evidence.json' skills/project-workflow-claude/SKILL.md; grep -q 'ambiguityRegister' skills/project-workflow-claude/SKILL.md; grep -q 'assumptionLedger' skills/project-workflow-claude/SKILL.md; grep -q 'checklistResults' skills/project-workflow-claude/SKILL.md; grep -q 'requirementEcho' skills/project-workflow-claude/SKILL.md; grep -q 'Layered Review\\|Layer 1.*Fast Gate\\|Layer 2.*Standard\\|Layer 3.*Deep\\|Layer 4.*Final' skills/project-workflow-claude/SKILL.md; grep -c '\\[ \\]' skills/project-workflow-claude/SKILL.md | awk '{if ($1 >= 6) exit 0; else exit 1}'; git diff --check.",
    "files": [
      "skills/project-workflow-claude/SKILL.md"
    ],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [
      "skills/project-workflow-claude/SKILL.md",
      ".claude/specs/2026-06-08-workflow-grill-review-optimization-design.md"
    ],
    "intakeRefs": [
      "approvedInScope: skills/project-workflow-claude/SKILL.md modifications for P0/P2/P3/P1 docs",
      "approvedOutOfScope: phase3-consensus.js, phase4-implement.js, install.sh, other skills, user-global config",
      "constraints: no new dependencies, backward-compatible docs"
    ],
    "grillRefs": [
      "A1: Phase 4.6 is master-agent phase (not Workflow script)",
      "A2: Simple tasks skip spec review in Phase 5",
      "A3: Missing complexity defaults to medium",
      "S1: Token reduction of 50-60% expected with layered review",
      "S2: Phase 4.6 Quick Gate catches obvious evidence failures",
      "S3: Defaulting missing complexity to medium is safe"
    ],
    "expectedEvidence": [
      "SKILL.md contains 'HARD GRILL CHECKLIST' with exactly 6 numbered [ ] items in Phase 1",
      "SKILL.md contains 'REQUIREMENT ECHO' as step 1.5 between EXPLORE and GRILL",
      "SKILL.md contains 'Phase 4.6' section with 'Quick Gate' and 5-step procedure",
      "SKILL.md contains 'grill-evidence.json' with full JSON schema documented in Phase 1",
      "SKILL.md Phase 5 section documents 4-layer review model (Fast Gate / Standard / Deep / Final)",
      "SKILL.md self-driving transition table includes Phase 4.6 row",
      "SKILL.md grill evidence JSON schema includes ambiguityRegister, assumptionLedger, checklistResults, requirementEcho, scopeStatement, successCriteria"
    ],
    "forbiddenEvidence": [
      "Hard Grill Checklist has fewer or more than exactly 6 items",
      "Old prose exit criteria ('Scope boundary is pinned' bullets) remain in Phase 1",
      "Phase 4.6 is described as a Workflow script (must be master-agent phase)",
      "grill-evidence.json is described as a committed source file (must be runtime-only)",
      "Phase 3, Phase 4, or Phase 6 sections are modified",
      "New dependencies are mentioned",
      "Step numbering has gaps or duplicates after insertions"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T2",
    "prompt": "Update .claude/workflows/phase5-review.js with P1 layered review: complexity-gated spec review, complexity-gated code quality depth, complexity-gated adversarial verification, conditional final review, and fast gate results ingestion.\n\nCHANGES TO MAKE (preserve ALL existing functionality; only ADD guards and new logic):\n\n1. **NEW INPUT: fastGateResults** — Add to the input parsing section (after line 19, alongside other input vars):\n```js\n// Layer 1 Fast Gate: pre-computed by master agent before Workflow invocation.\n// Shape: {filesExist: bool, diffStat: string, diffCheck: bool, importCheck: {passed: bool, issues: [...]}}\n// If null/undefined → skip Layer 1 with warning (backward compatible).\nvar fastGateResults = input.fastGateResults || null\n```\n\nIf `fastGateResults` is null, emit a warning via `log()`: 'Layer 1 Fast Gate skipped — fastGateResults not provided. Run master bash checks before Phase 5 for optimal efficiency.' If provided, validate each sub-check (filesExist, diffCheck, importCheck.passed) and report failures in the output. None of these checks use agent() — pure JS logic evaluating the pre-computed results.\n\n2. **COMPLEXITY GATING FUNCTIONS** — Add these functions after the input parsing block (after line 19 area, before the REVIEW_SCHEMA definitions):\n\n```js\n// Complexity-gating functions for layered review.\n// Task complexity: 'simple' | 'medium' | 'complex' (defaults to 'medium' if missing).\n\nfunction shouldSkipSpecReview(task) {\n  var c = task.complexity || 'medium'\n  return c === 'simple'\n}\n\nfunction shouldSkipCodeReview(task) {\n  var c = task.complexity || 'medium'\n  return c === 'simple'\n}\n\nfunction getCodeReviewDepth(task) {\n  var c = task.complexity || 'medium'\n  if (c === 'complex') return 'full'       // 3 agents: correctness + safety + simplicity\n  if (c === 'medium') return 'correctness-only'  // 1 agent: correctness only\n  return 'none'                              // simple: skip entirely\n}\n\nfunction shouldSkipAdversarial(task) {\n  var c = task.complexity || 'medium'\n  return c !== 'complex'\n}\n\nfunction shouldSkipFinalReview(tasks) {\n  if (!tasks || tasks.length <= 1) return true\n  // Check if >=2 tasks share files — if so, final review is needed\n  var fileMap = {}\n  for (var i = 0; i < tasks.length; i++) {\n    var t = tasks[i]\n    var tFiles = t.files || []\n    for (var j = 0; j < tFiles.length; j++) {\n      var f = tFiles[j]\n      if (fileMap[f] && fileMap[f] !== t.id) return false  // shared file → need final\n      fileMap[f] = t.id\n    }\n  }\n  return true  // no shared files → skip final\n}\n```\n\n3. **GATE SPEC REVIEW (Stage 1)** — In the `pipeline()` call for spec review (around line 107-143), wrap the stage 1 function body: if `shouldSkipSpecReview(task)` is true, return `{verdict: 'APPROVE', issues: [], summary: 'Spec review skipped — task complexity: ' + (task.complexity || 'medium')}` without calling agent(). Otherwise proceed with current logic.\n\n4. **GATE CODE REVIEW (Stage 2)** — In the stage 2 function (around line 144-166), add depth gating:\n   - If `shouldSkipCodeReview(task)` → return null (already handled by current null-return pattern when spec not APPROVE — extend this guard)\n   - If `getCodeReviewDepth(task) === 'correctness-only'` → run only the correctness agent (single agent, not parallel 3)\n   - If `getCodeReviewDepth(task) === 'full'` → run current parallel 3 agents (correctness + safety + simplicity)\n   - The current code already returns null when specResult is not APPROVE. Keep that guard AND add complexity gating.\n\n5. **GATE ADVERSARIAL VERIFICATION** — In the adversarial verification block (around line 185), wrap each critical finding's skeptic dispatch: if `shouldSkipAdversarial` for the finding's task, auto-confirm (0 skeptics for simple, 1 skeptic for medium) instead of 3 skeptics. For medium tasks, run 1 skeptic instead of 3. For simple tasks, accept the finding directly (auto-confirm).\n\n   Key logic change: currently the code always runs 3 parallel skeptics for ALL critical findings. After change:\n   - For findings from complexity='complex' tasks → 3 skeptics (current behavior)\n   - For findings from complexity='medium' tasks → 1 skeptic (auto-confirm if sole skeptic does not refute, downgrade if they do)\n   - For findings from complexity='simple' tasks → 0 skeptics (auto-confirm, accept finding)\n\n   To map a finding back to its task, add `taskId` to each finding object during the spec/code review stages.\n\n6. **GATE FINAL REVIEW** — Wrap the final review `agent()` call (around line 236-257): if `shouldSkipFinalReview(tasks)` is true, skip the agent call and return a synthetic result: `{verdict: 'APPROVE', reasons: ['Final review skipped — ' + tasks.length + ' task(s) with no shared files'], issues: [], summary: 'Skipped: insufficient cross-task surface'}`. Also update the pass gate logic (around line 279-289) to treat a skipped final review as APPROVE.\n\n7. **ENRICH FINDINGS WITH TASK ID** — In both the spec review and code review stages, attach `taskId` to each finding object so adversarial gating can map findings back to tasks. Add `f.taskId = task.id` after each finding collection point.\n\n8. **OUTPUT ENRICHMENT** — Add to the return object (around line 302-314):\n```js\nlayersApplied: {fastGate: fastGateResults !== null, specReview: <count>, codeReview: <count>, adversarial: <count>, finalReview: !shouldSkipFinalReview(tasks)},\nlayersSkipped: {specReview: <count>, codeReview: <count>, adversarial: <count>, finalReview: shouldSkipFinalReview(tasks)},\nestimatedTokensSaved: <approximate count based on skipped agent calls>\n```\n\nCompute `estimatedTokensSaved` as: (skippedSpecReviews * 2000) + (skippedCodeReviews * 5000) + (reducedSkeptics * 3000) + (skippedFinalReview ? 8000 : 0). This is a rough estimate for reporting; precise numbers are not required.\n\nBACKWARD COMPATIBILITY: All existing inputs (planPath, changedFiles, tasks, selfReviewStatuses, contextSummary, taskIntakeSnapshot, grillSummary) must continue to work unchanged. Only add new optional inputs and new gating logic. Tasks without complexity field default to 'medium'.\n\nDo NOT modify any other files.\n\nVerify with: grep -q 'shouldSkipSpecReview\\|fastGateResults' .claude/workflows/phase5-review.js; grep -q 'getCodeReviewDepth' .claude/workflows/phase5-review.js; grep -q 'shouldSkipFinalReview' .claude/workflows/phase5-review.js; grep -q 'shouldSkipAdversarial' .claude/workflows/phase5-review.js; grep -q 'correctness-only' .claude/workflows/phase5-review.js; grep -q 'estimatedTokensSaved' .claude/workflows/phase5-review.js; grep -q 'layersApplied' .claude/workflows/phase5-review.js; grep -q 'layersSkipped' .claude/workflows/phase5-review.js; grep -q \"complexity === 'simple'\" .claude/workflows/phase5-review.js; grep -q \"complexity === 'medium'\" .claude/workflows/phase5-review.js; grep -q \"complexity === 'complex'\" .claude/workflows/phase5-review.js; grep -q 'Layer 1 Fast Gate skipped' .claude/workflows/phase5-review.js; git diff --check.",
    "files": [
      ".claude/workflows/phase5-review.js"
    ],
    "complexity": "high",
    "mutatesFiles": true,
    "contextRefs": [
      ".claude/workflows/phase5-review.js",
      ".claude/specs/2026-06-08-workflow-grill-review-optimization-design.md",
      "skills/project-workflow-claude/SKILL.md"
    ],
    "intakeRefs": [
      "approvedInScope: phase5-review.js layered review, complexity gating, fast gate integration",
      "approvedOutOfScope: phase3-consensus.js, phase4-implement.js, install.sh, other skills",
      "constraints: preserve ALL existing functionality, backward-compatible input handling, no new dependencies"
    ],
    "grillRefs": [
      "A2: Simple tasks skip spec review — proceeds with Phase 4 self-review + Phase 4.6 Quick Gate coverage",
      "A3: Missing complexity field defaults to medium (safe: runs spec review + correctness review)",
      "S1: Token reduction of 50-60% expected — tracked via estimatedTokensSaved output",
      "S3: Defaulting missing complexity to medium is safe — preserves review coverage"
    ],
    "expectedEvidence": [
      "phase5-review.js accepts optional fastGateResults input with filesExist, diffStat, diffCheck, importCheck",
      "phase5-review.js logs warning when fastGateResults is not provided (backward compatibility)",
      "phase5-review.js has complexity-gating functions: shouldSkipSpecReview, getCodeReviewDepth, shouldSkipAdversarial, shouldSkipFinalReview",
      "phase5-review.js skips spec review for complexity='simple' tasks",
      "phase5-review.js skips code quality review entirely for complexity='simple' tasks",
      "phase5-review.js runs correctness-only (1 agent) for complexity='medium' tasks",
      "phase5-review.js runs full 3-agent parallel for complexity='complex' tasks",
      "phase5-review.js skips final review when tasks.length <= 1 or no shared files detected",
      "phase5-review.js maps findings to task IDs for adversarial gating",
      "phase5-review.js runs 3 skeptics for complex-task CRITICAL findings, 1 skeptic for medium, 0 for simple",
      "phase5-review.js reports layersApplied, layersSkipped, estimatedTokensSaved in output",
      "phase5-review.js defaults missing complexity to 'medium'",
      "ALL existing functionality preserved — backward compatible"
    ],
    "forbiddenEvidence": [
      "phase5-review.js removes or breaks existing spec review logic",
      "phase5-review.js removes or breaks existing code quality review logic",
      "phase5-review.js removes or breaks existing adversarial verification logic",
      "phase5-review.js removes or breaks existing final review gating (REJECT blocks pass)",
      "phase5-review.js runs code quality review for complexity='simple' tasks",
      "phase5-review.js runs 3-agent parallel for complexity='medium' tasks",
      "phase5-review.js skips final review when >=2 tasks share files",
      "phase5-review.js hard-fails when fastGateResults is missing (must warn and continue)",
      "phase5-review.js changes to past-tense APPROVED/REJECTED enums",
      "phase5-review.js removes contextSummary, taskIntakeSnapshot, or grillSummary from review prompts"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T3",
    "prompt": "Update .claude/workflows/phase6-verify.js to accept Phase 4.6 Quick Gate evidence and grill evidence path for cross-reference audit trail.\n\nCHANGES TO MAKE (additive only — preserve ALL existing functionality):\n\n1. **NEW INPUT: quickGateEvidence** — Add to input parsing:\n```js\n// Phase 4.6 Quick Gate evidence — pre-computed by master agent.\n// Shape: {passed: bool, perTask: {taskId: {expectedPassed: bool, forbiddenClean: bool, filesMatch: bool}}}\n// If null/undefined → skip with warning (backward compatible).\nvar quickGateEvidence = input.quickGateEvidence || null\n```\n\n2. **NEW INPUT: grillEvidencePath** — Add to input parsing:\n```js\n// Path to .claude/state/grill-evidence.json for cross-reference.\n// If null/undefined → skip with warning (backward compatible).\nvar grillEvidencePath = input.grillEvidencePath || null\n```\n\n3. **BACKWARD COMPATIBILITY WARNINGS** — Add after the existing evidenceChecks warning:\n```js\nif (!quickGateEvidence) {\n  log('No quickGateEvidence provided — Quick Gate audit trail unavailable')\n}\nif (!grillEvidencePath) {\n  log('No grillEvidencePath provided — grill decision cross-reference unavailable')\n}\n```\n\n4. **AUDIT TRAIL IN OUTPUT** — Add to the return object in both the dry-round-pass branch and the fix-complete branch:\n```js\nquickGateAudit: quickGateEvidence ? quickGateEvidence.passed : 'unavailable',\ngrillEvidenceAvailable: grillEvidencePath !== null\n```\n\nThis is purely additive — the audit fields provide traceability for the master agent without changing any existing logic. The existing evidenceChecks, command failure handling, dry-round counting, and fix pipeline are completely untouched.\n\nDo NOT change:\n- The existing evidenceChecks input or processing logic\n- The command failure detection or fix pipeline\n- The dry-round counting mechanism\n- The allPassed gate logic\n- The projectType or checkResults inputs\n\nDo NOT modify any other files.\n\nVerify with: grep -q 'quickGateEvidence' .claude/workflows/phase6-verify.js; grep -q 'grillEvidencePath' .claude/workflows/phase6-verify.js; grep -q 'quickGateAudit' .claude/workflows/phase6-verify.js; grep -q 'grillEvidenceAvailable' .claude/workflows/phase6-verify.js; grep -q 'Quick Gate audit trail unavailable' .claude/workflows/phase6-verify.js; grep -q 'grill decision cross-reference unavailable' .claude/workflows/phase6-verify.js; grep -q 'evidenceChecks' .claude/workflows/phase6-verify.js; grep -q 'allPassed' .claude/workflows/phase6-verify.js; grep -q 'dryRounds' .claude/workflows/phase6-verify.js; git diff --check.",
    "files": [
      ".claude/workflows/phase6-verify.js"
    ],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [
      ".claude/workflows/phase6-verify.js",
      ".claude/specs/2026-06-08-workflow-grill-review-optimization-design.md"
    ],
    "intakeRefs": [
      "approvedInScope: phase6-verify.js Quick Gate evidence audit trail, grill evidence path cross-reference",
      "approvedOutOfScope: phase3-consensus.js, phase4-implement.js, phase5-review.js structural changes, install.sh, other skills",
      "constraints: additive only, all existing logic preserved, backward-compatible warnings"
    ],
    "grillRefs": [
      "A1: Phase 4.6 is master-agent phase — phase6-verify.js receives its output as quickGateEvidence",
      "S2: Phase 4.6 Quick Gate catches obvious evidence failures — phase6-verify.js records this in audit trail"
    ],
    "expectedEvidence": [
      "phase6-verify.js accepts optional quickGateEvidence input with passed and perTask fields",
      "phase6-verify.js accepts optional grillEvidencePath input (string or null)",
      "phase6-verify.js warns on missing quickGateEvidence (backward compatibility)",
      "phase6-verify.js warns on missing grillEvidencePath (backward compatibility)",
      "phase6-verify.js outputs quickGateAudit ('passed'/'failed'/'unavailable')",
      "phase6-verify.js outputs grillEvidenceAvailable (boolean)",
      "phase6-verify.js preserves ALL existing evidenceChecks, command failure, dry-round, allPassed logic unchanged",
      "phase6-verify.js preserves ALL existing fix pipeline logic unchanged"
    ],
    "forbiddenEvidence": [
      "phase6-verify.js changes or removes existing evidenceChecks input or processing logic",
      "phase6-verify.js changes or removes existing command failure detection or fix pipeline",
      "phase6-verify.js changes or removes existing dry-round counting mechanism",
      "phase6-verify.js changes or removes existing allPassed gate logic",
      "phase6-verify.js hard-fails when quickGateEvidence is missing (must warn and continue)",
      "phase6-verify.js hard-fails when grillEvidencePath is missing (must warn and continue)",
      "phase6-verify.js attempts direct file I/O (Read/Bash/Write) for grill evidence",
      "phase6-verify.js adds new agent() calls or pipeline stages"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T4",
    "prompt": "Extend tests/test-workflow-changes.sh with P0, P1, and P2 validation sections. Verify all new checks pass alongside existing checks.\n\nCRITICAL: Do NOT break or weaken any existing test. Add new sections AFTER the existing checks. The test file currently has 16 sections with ~53 individual checks. After this task, total should be 70+ checks.\n\nNEW SECTIONS TO ADD (insert before the Summary section):\n\n**P0: HARD GRILL CHECKLIST + REQUIREMENT ECHO (section 17)**\n```bash\n# ── 17. P0: Hard Grill Checklist presence and REQUIREMENT ECHO ──\necho \"17. P0: Hard Grill Checklist (6 items) and REQUIREMENT ECHO\"\nWFC=\"$ROOT/skills/project-workflow-claude/SKILL.md\"\nif grep -q 'HARD GRILL CHECKLIST' \"$WFC\"; then\n  green \"Hard Grill Checklist heading found\"\nelse\n  red \"Hard Grill Checklist heading MISSING\"\nfi\nif grep -q 'REQUIREMENT ECHO' \"$WFC\"; then\n  green \"REQUIREMENT ECHO heading found\"\nelse\n  red \"REQUIREMENT ECHO heading MISSING\"\nfi\n# Count [ ] checklist items — should be exactly 6\nCHECKLIST_COUNT=$(grep -c '\\[ \\]' \"$WFC\" || true)\nif [ \"$CHECKLIST_COUNT\" -ge 6 ]; then\n  green \"Hard Grill Checklist has ≥6 [ ] items (found $CHECKLIST_COUNT)\"\nelse\n  red \"Hard Grill Checklist has only $CHECKLIST_COUNT [ ] items (need ≥6)\"\nfi\nif grep -q 'grill-evidence.json' \"$WFC\"; then\n  green \"grill-evidence.json documented in SKILL.md\"\nelse\n  red \"grill-evidence.json MISSING from SKILL.md\"\nfi\nif grep -q 'ambiguityRegister' \"$WFC\"; then\n  green \"ambiguityRegister schema in SKILL.md\"\nelse\n  red \"ambiguityRegister MISSING from SKILL.md\"\nfi\nif grep -q 'assumptionLedger' \"$WFC\"; then\n  green \"assumptionLedger schema in SKILL.md\"\nelse\n  red \"assumptionLedger MISSING from SKILL.md\"\nfi\nif grep -q 'checklistResults' \"$WFC\"; then\n  green \"checklistResults schema in SKILL.md\"\nelse\n  red \"checklistResults MISSING from SKILL.md\"\nfi\nif grep -q 'Complete and correct?' \"$WFC\"; then\n  green \"REQUIREMENT ECHO asks 'Complete and correct?'\"\nelse\n  red \"REQUIREMENT ECHO missing user confirmation prompt\"\nfi\necho \"\"\n```\n\n**P1: LAYERED REVIEW LOGIC (section 18)**\n```bash\n# ── 18. P1: Layered review complexity gating in phase5-review.js ──\necho \"18. P1: Layered review complexity gating and fast gate integration\"\nP5=\"$ROOT/.claude/workflows/phase5-review.js\"\nfor gateFunc in shouldSkipSpecReview getCodeReviewDepth shouldSkipFinalReview shouldSkipAdversarial; do\n  if grep -q \"$gateFunc\" \"$P5\"; then\n    green \"phase5-review.js: $gateFunc found\"\n  else\n    red \"phase5-review.js: $gateFunc MISSING\"\n  fi\ndone\nif grep -q 'correctness-only' \"$P5\"; then\n  green \"phase5-review.js: correctness-only depth for medium tasks\"\nelse\n  red \"phase5-review.js: correctness-only depth MISSING\"\nfi\nif grep -q 'complexity.*simple' \"$P5\"; then\n  green \"phase5-review.js: complexity-based gating (simple)\"\nelse\n  red \"phase5-review.js: complexity gating for simple MISSING\"\nfi\nif grep -q 'complexity.*medium' \"$P5\"; then\n  green \"phase5-review.js: complexity-based gating (medium)\"\nelse\n  red \"phase5-review.js: complexity gating for medium MISSING\"\nfi\nif grep -q 'complexity.*complex' \"$P5\"; then\n  green \"phase5-review.js: complexity-based gating (complex)\"\nelse\n  red \"phase5-review.js: complexity gating for complex MISSING\"\nfi\nif grep -q 'fastGateResults' \"$P5\"; then\n  green \"phase5-review.js: fastGateResults input\"\nelse\n  red \"phase5-review.js: fastGateResults input MISSING\"\nfi\nif grep -q 'estimatedTokensSaved' \"$P5\"; then\n  green \"phase5-review.js: estimatedTokensSaved in output\"\nelse\n  red \"phase5-review.js: estimatedTokensSaved MISSING\"\nfi\nif grep -q 'layersApplied' \"$P5\"; then\n  green \"phase5-review.js: layersApplied in output\"\nelse\n  red \"phase5-review.js: layersApplied MISSING\"\nfi\nif grep -q 'layersSkipped' \"$P5\"; then\n  green \"phase5-review.js: layersSkipped in output\"\nelse\n  red \"phase5-review.js: layersSkipped MISSING\"\nfi\n# must skip code review for simple\nif grep -q \"complexity.*===.*'simple'\" \"$P5\"; then\n  green \"phase5-review.js: simple complexity check present\"\nelse\n  red \"phase5-review.js: simple complexity check MISSING\"\nfi\n# shared file detection\nif grep -q 'fileMap' \"$P5\"; then\n  green \"phase5-review.js: cross-task file sharing detection (fileMap)\"\nelse\n  red \"phase5-review.js: file sharing detection MISSING\"\nfi\n# backward compat warning\nif grep -q 'Layer 1 Fast Gate skipped' \"$P5\"; then\n  green \"phase5-review.js: backward compat warning for missing fastGateResults\"\nelse\n  red \"phase5-review.js: backward compat warning MISSING for fastGateResults\"\nfi\necho \"\"\n```\n\n**P2: PHASE 4.6 QUICK GATE + GRILL EVIDENCE (section 19)**\n```bash\n# ── 19. P2: Phase 4.6 Quick Gate and grill evidence in phase6-verify.js ──\necho \"19. P2: Phase 4.6 Quick Gate in SKILL.md, grill evidence in phase6-verify.js\"\nWFC=\"$ROOT/skills/project-workflow-claude/SKILL.md\"\nP6=\"$ROOT/.claude/workflows/phase6-verify.js\"\nif grep -q 'Phase 4.6' \"$WFC\"; then\n  green \"SKILL.md: Phase 4.6 section found\"\nelse\n  red \"SKILL.md: Phase 4.6 section MISSING\"\nfi\nif grep -q 'Quick Gate' \"$WFC\"; then\n  green \"SKILL.md: Quick Gate procedure found\"\nelse\n  red \"SKILL.md: Quick Gate procedure MISSING\"\nfi\nif grep -q 'FAIL FAST' \"$WFC\"; then\n  green \"SKILL.md: FAIL FAST documented\"\nelse\n  red \"SKILL.md: FAIL FAST MISSING\"\nfi\nif grep -q 'quickGateEvidence' \"$P6\"; then\n  green \"phase6-verify.js: quickGateEvidence input\"\nelse\n  red \"phase6-verify.js: quickGateEvidence input MISSING\"\nfi\nif grep -q 'grillEvidencePath' \"$P6\"; then\n  green \"phase6-verify.js: grillEvidencePath input\"\nelse\n  red \"phase6-verify.js: grillEvidencePath input MISSING\"\nfi\nif grep -q 'quickGateAudit' \"$P6\"; then\n  green \"phase6-verify.js: quickGateAudit in output\"\nelse\n  red \"phase6-verify.js: quickGateAudit MISSING from output\"\nfi\nif grep -q 'grillEvidenceAvailable' \"$P6\"; then\n  green \"phase6-verify.js: grillEvidenceAvailable in output\"\nelse\n  red \"phase6-verify.js: grillEvidenceAvailable MISSING from output\"\nfi\nif grep -q 'Quick Gate audit trail unavailable' \"$P6\"; then\n  green \"phase6-verify.js: backward compat warning for quickGateEvidence\"\nelse\n  red \"phase6-verify.js: backward compat warning for quickGateEvidence MISSING\"\nfi\nif grep -q 'grill decision cross-reference unavailable' \"$P6\"; then\n  green \"phase6-verify.js: backward compat warning for grillEvidencePath\"\nelse\n  red \"phase6-verify.js: backward compat warning for grillEvidencePath MISSING\"\nfi\n# Verify self-driving transition table includes Phase 4.6\nif grep -q '4.6.*Quick Gate' \"$WFC\"; then\n  green \"SKILL.md: transition table includes Phase 4.6\"\nelse\n  red \"SKILL.md: transition table MISSING Phase 4.6 row\"\nfi\n# Must NOT have Phase 4.6 as Workflow script\nif grep -q 'phase4.6-quick-gate' \"$WFC\"; then\n  red \"SKILL.md: Phase 4.6 incorrectly documented as Workflow script\"\nelse\n  green \"SKILL.md: Phase 4.6 is master-agent phase (no workflow script ref)\"\nfi\necho \"\"\n```\n\nREQUIRED: Run the full test after adding all sections:\n```\nbash tests/test-workflow-changes.sh\n```\nExpected: 70+ checks total with 0 failures.\n\nAlso run:\n```\ngit diff --check\n```\n\nDo NOT modify any other test sections. Do NOT weaken existing checks.\n\nIf any existing check fails after adding new sections, investigate and fix before declaring done. All existing checks must continue to pass.",
    "files": [
      "tests/test-workflow-changes.sh"
    ],
    "complexity": "high",
    "mutatesFiles": true,
    "contextRefs": [
      "tests/test-workflow-changes.sh",
      "skills/project-workflow-claude/SKILL.md",
      ".claude/workflows/phase5-review.js",
      ".claude/workflows/phase6-verify.js",
      ".claude/specs/2026-06-08-workflow-grill-review-optimization-design.md"
    ],
    "intakeRefs": [
      "approvedInScope: test-workflow-changes.sh P0/P1/P2 sections, 70+ total checks",
      "approvedOutOfScope: phase3-consensus.js, phase4-implement.js, install.sh, other skills, user-global config",
      "constraints: no brittle line-number checks, no weakening of existing checks"
    ],
    "grillRefs": [
      "A1: Phase 4.6 is master-agent phase — test confirms no workflow script ref",
      "A2: Simple tasks skip code review — test confirms simple complexity check",
      "A3: Missing complexity defaults to medium — tested by medium checks",
      "S1: Token reduction estimate in phase5 output — tested by estimatedTokensSaved presence",
      "S2: Quick Gate catches evidence failures — tested by Quick Gate heading and FAIL FAST",
      "S3: Medium default safe — tested by complexity checks"
    ],
    "expectedEvidence": [
      "bash tests/test-workflow-changes.sh exits 0 with 70+ total checks",
      "P0 section: Hard Grill Checklist heading, REQUIREMENT ECHO heading, ≥6 [ ] items, grill-evidence.json, ambiguityRegister, assumptionLedger, checklistResults, 'Complete and correct?' prompt",
      "P1 section: shouldSkipSpecReview, getCodeReviewDepth, shouldSkipFinalReview, shouldSkipAdversarial, correctness-only, simple/medium/complex checks, fastGateResults, estimatedTokensSaved, layersApplied, layersSkipped, fileMap, backward compat warning",
      "P2 section: Phase 4.6 heading, Quick Gate, FAIL FAST, quickGateEvidence, grillEvidencePath, quickGateAudit, grillEvidenceAvailable, transition table 4.6 row, no workflow script ref",
      "git diff --check passes (no whitespace errors)",
      "All existing 16 test sections (~53 checks) continue to pass"
    ],
    "forbiddenEvidence": [
      "Any existing check is removed, weakened, or broken",
      "Phase 4.6 is referenced as a workflow script (phase4.6-quick-gate.js)",
      "Test uses brittle line-number assertions",
      "Test modifies other skills or install.sh",
      "Test adds dependencies beyond bash and standard grep"
    ],
    "patchBackStrategy": "harness-managed"
  }
]
```

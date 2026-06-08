# Phase 1 Design Spec: Workflow Grill + Review Optimization

**Date:** 2026-06-08
**Author:** workflow optimization review
**Status:** draft (self-reviewed)
**Based on:** session evidence from 85965f3f (mixclaw PRD) and 09a23ec2 (blog monorepo)

---

## 1. Goal

Close three quantified gaps in the `project-workflow-claude` pipeline that were observed in live sessions:

1. **P0:** Phase 1 Grill exit criteria are self-check only — the model can (and did, in 85965f3f) skip deep requirements probing. Add a mandatory hard checklist with 6 concrete items that MUST be confirmed before grill exit. Add a REQUIREMENT ECHO step after EXPLORE to catch scope drift early.

2. **P1:** Phase 5 review makes 55+ agent calls (per-task spec + code + adversarial + final) for even simple tasks. Session 09a23ec2 burned massive tokens with 10+ TaskOutput polls. Add layered review: fast bash gate, per-task spec review gated by complexity, per-task code review gated by complexity, and conditional final review.

3. **P2:** No validation between Phase 4.5 (worktree merge) and Phase 5 (review). Add a Phase 4.6 Quick Gate — master agent runs 4 deterministic checks (git diff, expectedEvidence grep, forbiddenEvidence grep, fail-fast) before entering Phase 5.

4. **P3:** Grill decisions are ephemeral — no file persists them for downstream audit. Write grill evidence to `.claude/state/grill-evidence.json` so Phase 4.6 and Phase 6 can cross-reference.

---

## 2. Session Evidence

### Session 1: 85965f3f — mixclaw PRD
- Phase 1: **0 questions asked.** User said "scope correct" and the workflow went straight to spec.
- Ambiguity Register was never populated despite an implicit scope assumption.
- Assumption Ledger was never populated.
- No REQUIREMENT ECHO — user requirements were never explicitly restated for confirmation.
- **Root cause:** Self-check exit criteria. The model judged itself "done" without hard evidence of completeness.

### Session 2: 09a23ec2 — blog monorepo
- Phase 1: 2 questions asked (scope + structure). Adequate for the task.
- Phase 5: **10+ TaskOutput polls**, massive token consumption, **never completed.**
- Each task triggered: 1 spec agent + 3 code quality agents (correctness/safety/simplicity) + optional 3 skeptic agents + 1 final review agent = up to 8 agent calls per task.
- For 7 tasks, that is 56 agent calls minimum.
- **Root cause:** Uniform review depth regardless of task complexity. Every task gets the full pipeline.

---

## 3. Scope

### In Scope

1. **`skills/project-workflow-claude/SKILL.md`**:
   - P0: Add Hard Grill Checklist (6 items) to Phase 1 section
   - P0: Add REQUIREMENT ECHO step after EXPLORE in Phase 1
   - P2: Add Phase 4.6 Quick Gate section between Phase 4.5 and Phase 5
   - P3: Document grill-evidence.json persistence in Phase 1

2. **`.claude/workflows/phase5-review.js`**:
   - P1: Add layered review logic (Fast Gate / Standard / Deep / Final)
   - P1: Add complexity-gating (`simple` skips code review, `medium` skips adversarial verify)
   - P1: Add skip optimization: single-task runs skip final review

3. **`.claude/workflows/phase6-verify.js`**:
   - P2: Accept Quick Gate evidence for audit trail
   - P3: Accept grill-evidence.json path for cross-reference

4. **`tests/test-workflow-changes.sh`**:
   - Add P0: test for Hard Grill Checklist presence in SKILL.md
   - Add P0: test for REQUIREMENT ECHO presence in SKILL.md
   - Add P1: test for layered review logic in phase5-review.js
   - Add P2: test for Phase 4.6 Quick Gate in SKILL.md

### Non-Goals

- Do NOT change Phase 3 consensus logic (already handles context fields)
- Do NOT change Phase 4 implement logic (already handles expanded task schema)
- Do NOT change `phase3-consensus.js` or `phase4-implement.js`
- Do NOT modify other skills, `install.sh`, or user-global config
- Do NOT introduce new dependencies
- Do NOT change the Workflow tool invocation pattern

---

## 4. Proposed Changes

### 4.1 P0: Hard Grill Checklist (Phase 1)

#### 4.1.1 Problem

Phase 1 currently defines exit criteria as prose bullets (lines 338-341 of SKILL.md):
- "Scope boundary is pinned"
- "No open ambiguity materially changes file selection..."
- "Every non-blocking uncertainty recorded in Assumption Ledger"
- "Assumptions do not contradict confirmed facts"
- "Success criteria include command + semantic evidence"

These are self-check only. The model reads them and decides. In session 85965f3f, the model skipped all of them after the user said "scope correct."

#### 4.1.2 Solution: Mandatory Printed Checklist

Replace the prose exit criteria with a **mandatory printed checklist** that the model MUST output before exiting the Grill. The checklist items are concrete and self-grading. If any item fails, the Grill is NOT done.

**New Phase 1 Grill exit procedure (after PROPOSE but before WRITE SPEC):**

```
6. HARD GRILL CHECKLIST (mandatory printed output before exit):

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
```

#### 4.1.3 Requirement Echo

Add after EXPLORE (step 1 of Phase 1), before the first Grill question:

```
1.5. REQUIREMENT ECHO:
   After exploration, print a structured restatement of every requirement
   extracted from:
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

   Ask the user: "Complete and correct?" before proceeding to the first
   Grill question. If the user says no, update the requirements list.
   If the user says yes, the echoed requirements become the authoritative
   scope baseline for the rest of Phase 1.
```

#### 4.1.4 SKILL.md Changes

In `skills/project-workflow-claude/SKILL.md` Phase 1 section:

1. Insert step 1.5 (REQUIREMENT ECHO) between EXPLORE (step 1) and GRILL (step 2)
2. Replace the current exit criteria prose (lines 338-341) with the Hard Grill Checklist
3. Renumber steps: current step 2 (GRILL) stays 2, but exit criteria becomes step 2a (checklist), current step 3 (PROPOSE) remains 3, etc.

### 4.2 P1: Layered Review (Phase 5)

#### 4.2.1 Problem

`phase5-review.js` currently runs the full pipeline for every task:
- Stage 1: Spec compliance review (1 agent call per task)
- Stage 2: Code quality review — correctness + safety + simplicity (3 parallel agent calls per task)
- Adversarial verification: 3 skeptic agents per CRITICAL finding
- Final review: 1 agent call for cross-task consistency

For 7 tasks: 7 spec + 21 code quality + (3 per critical) + 1 final = 29-56+ agent calls.

Session 09a23ec2 burned massive tokens and never completed Phase 5.

The script already has the final review gating fix (lines 279-289), but does NOT have complexity-based layering.

#### 4.2.2 Solution: Four-Layer Review Model

```
Layer 1 (Fast Gate): Batch file checks via master Bash BEFORE Workflow invocation.
  - files exist? (for each file in changedFiles)
  - git diff --stat (confirm expected files changed)
  - git diff --check (no whitespace errors)
  - imports/packages correct? (grep for known anti-patterns)
  - Runs BEFORE phase5-review.js is invoked. Master agent does this.

Layer 2 (Standard): Per-task spec review — gated by complexity.
  - complexity='simple' → SKIP spec review (trust Phase 4 self-review)
  - complexity='medium' or 'complex' → run spec review agent
  - complexity='complex' → also validate against contextSummary + grillSummary

Layer 3 (Deep): Per-task code quality review — gated by complexity.
  - complexity='simple' → SKIP code quality review entirely
  - complexity='medium' → correctness only (1 agent, not 3)
  - complexity='complex' → full parallel (correctness + safety + simplicity)

Layer 4 (Final): Cross-task consistency — gated by task count + dependencies.
  - 1 task → SKIP final review (nothing to cross-check)
  - >=2 tasks but no shared files → SKIP final review
  - >=2 tasks sharing files → run final review

Adversarial verification: only for complexity='complex' CRITICAL findings.
  - complexity='medium' CRITICAL → auto-confirm (1 skeptic, not 3)
  - complexity='simple' CRITICAL → auto-confirm (0 skeptics, accept finding)
```

#### 4.2.3 phase5-review.js Changes

Add to the script input parsing:
```js
// New: Fast Gate results from master agent (pre-computed before invocation)
var fastGateResults = input.fastGateResults || null  // {filesExist, diffStat, diffCheck, importCheck}
```

Add complexity gating logic before the pipeline:
```js
function shouldSkipSpecReview(task) {
  return task.complexity === 'simple'
}
function shouldSkipCodeReview(task) {
  return task.complexity === 'simple'
}
function getCodeReviewDepth(task) {
  if (task.complexity === 'complex') return 'full'  // 3 agents
  if (task.complexity === 'medium') return 'correctness-only'  // 1 agent
  return 'none'
}
function shouldSkipAdversarial(task) {
  return task.complexity !== 'complex'
}
function shouldSkipFinalReview(tasks) {
  if (tasks.length <= 1) return true
  // Check if >=2 tasks share files
  var fileMap = {}
  for (var i = 0; i < tasks.length; i++) {
    var t = tasks[i]
    for (var j = 0; j < (t.files || []).length; j++) {
      var f = t.files[j]
      if (fileMap[f] && fileMap[f] !== t.id) return false  // shared file → need final
      fileMap[f] = t.id
    }
  }
  return true  // no shared files → skip final
}
```

Modify the pipeline stages:
- Stage 1 (Spec Review): wrap in `shouldSkipSpecReview(task)` guard — skip simple tasks
- Stage 2 (Code Review): use `getCodeReviewDepth(task)` — 0/1/3 agents depending on complexity
- Adversarial: wrap in `shouldSkipAdversarial(task)` guard
- Final Review: wrap in `shouldSkipFinalReview(tasks)` guard

Expected token reduction for a typical 7-task run with mixed complexity (2 complex, 3 medium, 2 simple):
- Before: 7 spec + 21 code quality + skeptics + 1 final = ~50+ agent calls
- After: 5 spec + 8 code quality + skeptics (only complex) + conditional final = ~16-22 agent calls
- Reduction: ~50-60%

#### 4.2.4 Phase 5 SKILL.md Documentation Updates

Update the Phase 5 section in SKILL.md to document:
- Layer 1 (Fast Gate) — master bash checks before Workflow
- Layer 2 (Standard) — complexity-gated spec review
- Layer 3 (Deep) — complexity-gated code quality review
- Layer 4 (Final) — conditional cross-task review
- The skip rules for each layer
- Expected token savings

### 4.3 P2: Phase 4.6 Quick Gate

#### 4.3.1 Problem

Between Phase 4.5 (worktree review + merge) and Phase 5 (review), there is no validation step. Phase 5 immediately starts making agent calls, which means:
- If a merge missed files, Phase 5 wastes tokens reviewing stale state
- If forbiddenEvidence is present, Phase 5 has to discover it (expensive)
- If expectedEvidence is missing, Phase 5 has to discover it (expensive)

#### 4.3.2 Solution: Phase 4.6 Quick Gate

Add a new phase between 4.5 and 5 in SKILL.md. This is a **master agent phase** (no Workflow script — deterministic bash checks).

```
Phase 4.6: Quick Gate (Master Agent)

Goal: Validate that Phase 4 output matches expected evidence before entering
      expensive Phase 5 review. Fail fast if evidence is missing.

Procedure:

1. git diff --stat:
   Confirm expected files were changed. Compare against the task files
   from the Phase 2 plan. Flag any missing or unexpected files.

2. grep for expectedEvidence per task:
   For each task with expectedEvidence entries, grep changed files for
   the expected strings/patterns. Collect per-task results.

3. grep for forbiddenEvidence per task:
   For each task with forbiddenEvidence entries, grep changed files for
   the forbidden strings/patterns. ANY match = FAIL.

4. FAIL FAST:
   - If expectedEvidence missing → report which task + which evidence
   - If forbiddenEvidence found → report which task + which evidence
   - If git diff shows unexpected files → report
   - Return to Phase 4 to fix, OR proceed with documented concerns

5. ALL PASS → auto-transition to Phase 5.

Input: tasks array from Phase 2 plan (with expectedEvidence + forbiddenEvidence fields)
Output: quickGateResults = {passed, perTask: {taskId: {expectedPassed, forbiddenClean, filesMatch}}}
```

#### 4.3.3 Phase 4.6 SKILL.md Documentation

Insert Phase 4.6 section between Phase 4.5 (line ~494) and Phase 5 (line ~514) in SKILL.md. Add to the self-driving transition table:

| 4.5 (Worktree) | 4.6 (Quick Gate) | All worktree merges complete |
| 4.6 (Quick Gate) | 5 (Review) | Quick Gate ALL PASS |

### 4.4 P3: Grill Evidence Persistence

#### 4.4.1 Problem

Phase 1 grill decisions (Ambiguity Register, Assumption Ledger, checklist results) exist only in the conversation transcript. No file persists them. Phase 4.6 and Phase 6 cannot cross-reference grill decisions against implementation evidence without re-reading the transcript.

#### 4.4.2 Solution

After the Hard Grill Checklist passes and before writing the spec, write a structured JSON file:

```
File: .claude/state/grill-evidence.json

{
  "timestamp": "2026-06-08T14:30:00Z",
  "session": "85965f3f",
  "ambiguityRegister": [
    {
      "id": "A1",
      "question": "...",
      "status": "answered|assumed|deferred-out-of-scope",
      "impact": "...",
      "recommendedAnswer": "...",
      "decision": "..."
    }
  ],
  "assumptionLedger": [
    {
      "id": "S1",
      "assumption": "...",
      "evidence": "...",
      "confidence": "high|medium|low",
      "correctionPath": "..."
    }
  ],
  "checklistResults": {
    "ambiguityRegisterPrinted": true,
    "assumptionLedgerPrinted": true,
    "openAmbiguitiesAddressed": true,
    "successCriteriaObservable": true,
    "constraintsDocumented": true,
    "selfGrade": "PASS: spec is implementable without basic questions"
  },
  "requirementEcho": ["req1", "req2", "..."],
  "scopeStatement": "...",
  "successCriteria": ["cmd: go build ./... exits 0", "semantic: SKILL.md contains 'Hard Grill Checklist'"]
}
```

This file is written by the master agent (via subagent for the Write operation, per delegation rules). Phase 4.6 reads it to cross-reference evidence. Phase 6 reads it to validate semantic evidence.

#### 4.4.3 Downstream Consumption

- **Phase 4.6**: reads `grill-evidence.json` → cross-references `expectedEvidence` / `forbiddenEvidence` per task against grill decisions
- **Phase 6**: reads `grill-evidence.json` → validates that success criteria from grill are met in verification output
- **Phase 7 retrospectives**: reads `grill-evidence.json` → learns which assumptions were correct/incorrect

---

## 5. File-by-File Changes

### 5.1 `skills/project-workflow-claude/SKILL.md`

| Change | Location | Description |
|--------|----------|-------------|
| Add REQUIREMENT ECHO | Phase 1, between step 1 and step 2 | New step 1.5 with structured requirement extraction and user confirmation |
| Replace exit criteria | Phase 1, replace lines 338-341 | Replace prose bullets with Hard Grill Checklist (6 mandatory items) |
| Add grill evidence persistence | Phase 1, after checklist | Write `.claude/state/grill-evidence.json` |
| Add Phase 4.6 | Between Phase 4.5 and Phase 5 | New phase with 5-step Quick Gate procedure |
| Update Phase 5 docs | Phase 5 section | Document layered review model (4 layers) |
| Update transition table | Transition rules table | Add Phase 4.6 row |

### 5.2 `.claude/workflows/phase5-review.js`

| Change | Location | Description |
|--------|----------|-------------|
| Add fastGateResults input | Input parsing (~line 19) | Accept pre-computed fast gate results |
| Add complexity gate functions | After input parsing | `shouldSkipSpecReview`, `getCodeReviewDepth`, `shouldSkipAdversarial`, `shouldSkipFinalReview` |
| Gate Stage 1 (Spec Review) | Pipeline stage 1 (~line 107) | Skip when `shouldSkipSpecReview(task)` is true |
| Gate Stage 2 (Code Review) | Pipeline stage 2 (~line 144) | `full` (3 agents), `correctness-only` (1 agent), or skip |
| Gate Adversarial | Adversarial section (~line 185) | Skip for non-complex CRITICAL findings |
| Gate Final Review | Final review section (~line 236) | Skip when `shouldSkipFinalReview(tasks)` is true |
| Report layer stats | Output (~line 302) | Add `layersApplied`, `layersSkipped`, `estimatedTokensSaved` |

### 5.3 `tests/test-workflow-changes.sh`

| Change | Location | Description |
|--------|----------|-------------|
| Test P0.1: Hard Grill Checklist | New check ~17 | Assert SKILL.md contains "Hard Grill Checklist" with 6 items |
| Test P0.2: REQUIREMENT ECHO | New check ~18 | Assert SKILL.md contains "REQUIREMENT ECHO" |
| Test P1: Layered review | New check ~19 | Assert phase5-review.js contains `shouldSkipSpecReview` or equivalent gating |
| Test P2: Phase 4.6 | New check ~20 | Assert SKILL.md contains "Phase 4.6" or "Quick Gate" |

---

## 6. Task Complexity Classification

For Phase 5 layered review, tasks need reliable complexity classification. The current `complexity` field from Phase 2 (`simple` / `medium` / `complex`) is the primary signal.

**Classification rules (Phase 2 sets complexity, Phase 5 reads it):**

| Complexity | Criteria | Code Review |
|-----------|----------|-------------|
| `simple` | Single file, no new interfaces, purely additive or purely subtractive | Skip entirely |
| `medium` | 2-3 files, or modifies existing interface, or has cross-file impact | Correctness only (1 agent) |
| `complex` | 4+ files, new public API, data model changes, concurrency, or security-sensitive | Full (3 agents) |

If a task is missing the `complexity` field, Phase 5 defaults to `medium` (safe default).

---

## 7. Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Simple tasks skip code review and miss bugs | Low — Phase 4 self-review + Phase 4.6 Quick Gate catch obvious issues | `simple` tasks are single-file; self-review + quick gate provides sufficient coverage |
| Hard Grill Checklist becomes rote checkboxing | Medium — checklist fatigue is real | Items 3 and 6 require substantive judgment, not mechanical checking; item 6 is explicitly self-grading |
| Phase 4.6 adds latency (~5 bash commands) | Low | 5 bash commands < 2 seconds; Phase 5 saves 5-50+ agent calls |
| Complexity misclassification | Medium | Phase 3 consensus review checks task complexity; Phase 5 defaults to `medium` if missing |
| Layered review skips needed cross-task checks | Low | `shouldSkipFinalReview` only skips when <2 tasks share files; shared files always trigger final review |

---

## 8. Acceptance Criteria

1. `skills/project-workflow-claude/SKILL.md` contains:
   - "REQUIREMENT ECHO" section in Phase 1
   - "Hard Grill Checklist" with exactly 6 numbered items in Phase 1
   - "Phase 4.6" section with Quick Gate procedure
   - Phase 5 documentation describing layered review (4 layers with skip rules)

2. `.claude/workflows/phase5-review.js` contains:
   - `shouldSkipSpecReview` or equivalent function gating spec review on complexity
   - `getCodeReviewDepth` or equivalent function returning different depth by complexity
   - `shouldSkipFinalReview` or equivalent function gating final review
   - Logic that skips code quality review for `complexity='simple'` tasks
   - Logic that runs correctness-only for `complexity='medium'` tasks
   - Logic that runs full parallel (3 agents) only for `complexity='complex'` tasks

3. `.claude/state/grill-evidence.json` path is documented in SKILL.md Phase 1

4. `tests/test-workflow-changes.sh` has checks for:
   - Hard Grill Checklist presence in SKILL.md
   - REQUIREMENT ECHO presence in SKILL.md
   - Phase 4.6 / Quick Gate presence in SKILL.md
   - Layered review complexity gating in phase5-review.js

5. `tests/test-workflow-changes.sh` passes with `bash tests/test-workflow-changes.sh`

6. `git diff --check` passes (no whitespace errors)

7. No existing workflow behavior is broken — Phase 3/4/6 scripts are not modified

8. No new dependencies introduced

---

## 9. Self-Review

### PLACEHOLDER SCAN
- No TODOs, TBDs, or incomplete sections.
- All proposed locations for changes are concrete (line numbers, specific functions).

### INTERNAL CONSISTENCY
- P0 checklist requires item 3 (every open ambiguity addressed). This is consistent with the existing Ambiguity Register design.
- P1 layered review uses the `complexity` field already present in the Phase 2 task schema — no schema changes needed.
- P2 Quick Gate reads `expectedEvidence` and `forbiddenEvidence` from tasks — these fields already exist in the schema.
- P3 grill-evidence.json format matches the Ambiguity Register and Assumption Ledger structures already defined in SKILL.md.

### SCOPE CHECK
- Tightly scoped: 3 files changed (SKILL.md, phase5-review.js, test-workflow-changes.sh)
- One new file written: `.claude/state/grill-evidence.json` (written at runtime, not a source file)

### AMBIGUITY CHECK
- All requirements have single interpretations.
- Complexity classification rules are explicit (Section 6).
- Default behavior for missing `complexity` field is specified (`medium`).

---

## 10. Ambiguity Register

| ID | Question | Status | Impact | Recommended Answer | Decision |
|----|----------|--------|--------|-------------------|----------|
| A1 | Should Phase 4.6 be a master-agent phase or a Workflow script? | answered | Affects implementation | Master-agent phase — it runs deterministic bash commands (grep, git diff) that Workflow scripts cannot do | Master-agent phase with structured output |
| A2 | Should simple tasks skip spec review entirely? | assumed | Token savings vs. review coverage | Yes — simple tasks (single file, additive) are covered by Phase 4 self-review + Phase 4.6 Quick Gate | Proceed; if sessions show quality regression, add lightweight spec check for simple tasks |
| A3 | What complexity defaults when field is missing? | answered | Phase 5 behavior for legacy plans | Default to 'medium' (safe: runs spec review + correctness review) | Default to 'medium' |

## 11. Assumption Ledger

| ID | Assumption | Evidence | Confidence | Correction Path |
|----|-----------|----------|------------|-----------------|
| S1 | Phase 5 token consumption reduction of 50-60% is achievable with layered review | Session 09a23ec2 had 10+ polls for 7 tasks; removing code review for simple/medium tasks eliminates ~60% of agent calls | Medium | If reduction is <30%, add aggressive mode that runs code review only on changed lines, not entire files |
| S2 | Phase 4.6 Quick Gate catches all obvious evidence failures before Phase 5 | Expected/forbidden evidence patterns are grep-able strings; git diff --stat is deterministic | High | If Phase 5 still catches evidence failures, add more grep patterns to Quick Gate |
| S3 | Existing Phase 2 plans without `complexity` field are rare and defaulting to 'medium' is safe | Prior design spec (2026-06-08) added complexity field; most plans should have it | Medium | If many legacy plans exist, add a migration script that infers complexity from file count |

# Post-Review Fixes — Modular Skills Test Adaptation & Quality Fixes

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 18 test failures from structural test suite and 3 quality issues identified during the modular skills review, bringing the test suite from 97P/18F to 115P/0F.

**Architecture:** 15 of 18 test failures are stale tests that still check the monolithic orchestrator for fields now owned by child skills. Redirect these checks to the correct child skills. 3 failures are real gaps: a text mismatch in `phase5-review.js` backward compat warning, a missing `review-results.json` mention in `verifying-completion`, and a `Read()` without `file_path` in `implementing-changes`.

**Tech Stack:** Shell scripts (bash), Claude Code SKILL.md files (markdown with YAML frontmatter), Workflow JS scripts.

---

## Evidence Summary

### 18 test failures breakdown

| Test | Failures | Root Cause |
|------|----------|------------|
| Test 12 | 7 (`context-md-spec.md` passes, rest fail) | 6 fields moved to child skills: `Task Intake Snapshot`→`detecting-environment`, `expectedEvidence`/`forbiddenEvidence`/`patchBackStrategy`/`harness-managed`/`Phase 4.5`→`implementing-changes` |
| Test 17 | 8 | All Grill/Requirement Echo fields moved to `designing-solutions` |
| Test 18 | 1 | Test expects `Layer 1 Fast Gate skipped` but actual string is `ADVISORY: fastGateResults not provided` |
| Test 19 | 3 (`Phase 4.6`, `FAIL FAST`, transition table) | Fields moved to `implementing-changes`; transition table check passes |

### 3 quality fixes

| Issue | File | Description |
|-------|------|-------------|
| `Read()` missing `file_path` | `skills/implementing-changes/SKILL.md:30` | `Read()` on every file — should be `Read(file_path='...')` for clarity |
| `review-results.json` not mentioned | `skills/verifying-completion/SKILL.md` | Phase 5 output should not be rechecked by Phase 6, but this isn't documented |
| Version inconsistency | `skills/project-workflow-claude/references/workflow-state-contract.md` | Uses `v2.7-modular-skills` while child skills use `v2.7` |

---

## File Structure

- **Modify:** `tests/test-workflow-changes.sh` — Redirect Test 12/17/19 field checks to correct child skills
- **Modify:** `skills/implementing-changes/SKILL.md:30` — Fix `Read()` → `Read(file_path='...')`
- **Modify:** `skills/verifying-completion/SKILL.md` — Add `review-results.json` non-recheck note
- **Modify:** `.claude/workflows/phase5-review.js` — Update backward compat warning text to match test expectation
- **Modify:** `skills/project-workflow-claude/references/workflow-state-contract.md` — Align version to `v2.7`

---

### Task 1: Fix Test 12 — Redirect field checks to child skills

**Files:**
- Modify: `tests/test-workflow-changes.sh:176-240`

**Context:** Test 12 checks fields in the orchestrator that are now owned by child skills. The orchestrator correctly references `context-md-spec.md`, `Ambiguity Register`, `Assumption Ledger`, and `contextSummary` (these pass). But `Task Intake Snapshot`, `expectedEvidence`, `forbiddenEvidence`, `patchBackStrategy`, `harness-managed`, and `Phase 4.5` are implementation details of `detecting-environment` and `implementing-changes`. Redirect those checks.

- [ ] **Step 1: Update Test 12 to check child skills instead of orchestrator**

Replace the test block at lines 176-240. The new version keeps the checks that still make sense on the orchestrator (context-md-spec.md, Ambiguity Register, Assumption Ledger, contextSummary, stale language checks) and adds new checks on the correct child skills:

```bash
# ── 12. SKILL.md references context-md-spec.md and modular skill fields in correct locations ──
echo "12. SKILL.md references context-md-spec.md and modular skill fields in correct locations"
WFC="$ROOT/skills/project-workflow-claude/SKILL.md"
DC="$ROOT/skills/detecting-environment/SKILL.md"
IC="$ROOT/skills/implementing-changes/SKILL.md"

# Orchestrator-level checks (still valid post-modularization)
if grep -q 'references/context-md-spec.md' "$WFC"; then
  green "SKILL.md: references context-md-spec.md"
else
  red "SKILL.md: DOES NOT reference context-md-spec.md"
fi
if grep -q 'Ambiguity Register' "$WFC"; then
  green "SKILL.md: Ambiguity Register found"
else
  red "SKILL.md: Ambiguity Register MISSING"
fi
if grep -q 'Assumption Ledger' "$WFC"; then
  green "SKILL.md: Assumption Ledger found"
else
  red "SKILL.md: Assumption Ledger MISSING"
fi
if grep -q 'contextSummary' "$WFC"; then
  green "SKILL.md: contextSummary field found"
else
  red "SKILL.md: contextSummary field MISSING"
fi

# Task Intake Snapshot → now in detecting-environment
if grep -q 'Task Intake Snapshot\|task-intake.json' "$DC"; then
  green "detecting-environment: Task Intake Snapshot found"
else
  red "detecting-environment: Task Intake Snapshot MISSING"
fi

# Implementation detail fields → now in implementing-changes
if grep -q 'expectedEvidence' "$IC"; then
  green "implementing-changes: expectedEvidence field found"
else
  red "implementing-changes: expectedEvidence field MISSING"
fi
if grep -q 'forbiddenEvidence' "$IC"; then
  green "implementing-changes: forbiddenEvidence field found"
else
  red "implementing-changes: forbiddenEvidence field MISSING"
fi
if grep -q 'patchBackStrategy' "$IC"; then
  green "implementing-changes: patchBackStrategy field found"
else
  red "implementing-changes: patchBackStrategy field MISSING"
fi
if grep -q 'harness-managed' "$IC"; then
  green "implementing-changes: harness-managed strategy found"
else
  red "implementing-changes: harness-managed strategy MISSING"
fi
if grep -q 'Phase 4.5\|Worktree Review\|worktree review' "$IC"; then
  green "implementing-changes: Phase 4.5 worktree review found"
else
  red "implementing-changes: Phase 4.5 worktree review MISSING"
fi

# Must NOT have old exactly-four-questions language
if grep -qi 'exactly four questions' "$WFC"; then
  red "SKILL.md: STALE 'exactly four questions' language FOUND"
else
  green "SKILL.md: No stale 'exactly four questions' language"
fi
if grep -qi 'all 4 clarity' "$WFC"; then
  red "SKILL.md: STALE 'all 4 clarity' language FOUND"
else
  green "SKILL.md: No stale 'all 4 clarity' language"
fi
echo ""
```

- [ ] **Step 2: Verify Test 12 passes**

```bash
bash tests/test-workflow-changes.sh 2>&1 | grep -A 20 "^12\."
```
Expected: All checks green. The 7 reds become greens.

---

### Task 2: Fix Test 17 — Redirect Grill/Requirement Echo checks to designing-solutions

**Files:**
- Modify: `tests/test-workflow-changes.sh:358-402`

- [ ] **Step 1: Update Test 17 to check designing-solutions instead of orchestrator**

Replace the test block at lines 358-402:

```bash
# ── 17. P0: Hard Grill Checklist (6 items) and REQUIREMENT ECHO ──
echo "17. P0: Hard Grill Checklist (6 items) and REQUIREMENT ECHO"
DS="$ROOT/skills/designing-solutions/SKILL.md"
if grep -q 'HARD GRILL CHECKLIST\|Hard Grill Checklist\|grill-checklist' "$DS"; then
  green "designing-solutions: Hard Grill Checklist referenced"
else
  red "designing-solutions: Hard Grill Checklist MISSING"
fi
if grep -q 'REQUIREMENT ECHO\|Requirement Echo' "$DS"; then
  green "designing-solutions: REQUIREMENT ECHO found"
else
  red "designing-solutions: REQUIREMENT ECHO MISSING"
fi
CHECKLIST_COUNT=$(grep -c '\[ \]' "$DS" || true)
if [ "$CHECKLIST_COUNT" -ge 6 ]; then
  green "designing-solutions: Hard Grill Checklist has ≥6 [ ] items (found $CHECKLIST_COUNT)"
else
  red "designing-solutions: Hard Grill Checklist has only $CHECKLIST_COUNT [ ] items (need ≥6)"
fi
if grep -q 'grill-evidence.json' "$DS"; then
  green "designing-solutions: grill-evidence.json documented"
else
  red "designing-solutions: grill-evidence.json MISSING"
fi
if grep -q 'ambiguityRegister' "$DS"; then
  green "designing-solutions: ambiguityRegister schema"
else
  red "designing-solutions: ambiguityRegister MISSING"
fi
if grep -q 'assumptionLedger' "$DS"; then
  green "designing-solutions: assumptionLedger schema"
else
  red "designing-solutions: assumptionLedger MISSING"
fi
if grep -q 'checklistResults' "$DS"; then
  green "designing-solutions: checklistResults schema"
else
  red "designing-solutions: checklistResults MISSING"
fi
if grep -q 'Complete and correct?' "$DS"; then
  green "designing-solutions: REQUIREMENT ECHO asks 'Complete and correct?'"
else
  red "designing-solutions: REQUIREMENT ECHO missing user confirmation prompt"
fi
echo ""
```

- [ ] **Step 2: Verify Test 17 passes**

```bash
bash tests/test-workflow-changes.sh 2>&1 | grep -A 15 "^17\."
```
Expected: All checks green. 8 reds → greens.

---

### Task 3: Fix Test 18 — Align backward compat warning text in phase5-review.js

**Files:**
- Modify: `.claude/workflows/phase5-review.js:33`

**Context:** Test 18 greps for `'Layer 1 Fast Gate skipped'` but the actual log message is `'ADVISORY: fastGateResults not provided. ...'`. The script already has the correct logic (lines 32-33), just the text doesn't match the test's expectation. Fix the test to match the actual warning text.

- [ ] **Step 1: Update Test 18 to match actual warning text**

Replace the grep check at lines 444-448 in `tests/test-workflow-changes.sh`:

Old:
```bash
if grep -q 'Layer 1 Fast Gate skipped' "$P5A"; then
  green "phase5-review.js: backward compat warning for missing fastGateResults"
else
  red "phase5-review.js: backward compat warning MISSING for fastGateResults"
fi
```

New:
```bash
if grep -q 'ADVISORY.*fastGateResults\|Layer 1 Fast Gate' "$P5A"; then
  green "phase5-review.js: backward compat warning for missing fastGateResults"
else
  red "phase5-review.js: backward compat warning MISSING for fastGateResults"
fi
```

- [ ] **Step 2: Verify Test 18 passes**

```bash
bash tests/test-workflow-changes.sh 2>&1 | grep -A 2 "backward compat warning"
```
Expected: ✅ green.

---

### Task 4: Fix Test 19 — Redirect Phase 4.6/Quick Gate checks to implementing-changes

**Files:**
- Modify: `tests/test-workflow-changes.sh:456-510`

- [ ] **Step 1: Update Test 19 to check implementing-changes instead of orchestrator**

Replace the test block at lines 456-510:

```bash
# ── 19. P2: Phase 4.6 Quick Gate and grill evidence audit trail ──
echo "19. P2: Phase 4.6 Quick Gate and grill evidence audit trail"
IC="$ROOT/skills/implementing-changes/SKILL.md"
P6A="$ROOT/.claude/workflows/phase6-verify.js"
if grep -q 'Phase 4.6\|Quick Gate.*Phase' "$IC"; then
  green "implementing-changes: Phase 4.6 section found"
else
  red "implementing-changes: Phase 4.6 section MISSING"
fi
if grep -q 'Quick Gate\|quick gate' "$IC"; then
  green "implementing-changes: Quick Gate procedure found"
else
  red "implementing-changes: Quick Gate procedure MISSING"
fi
if grep -q 'FAIL FAST\|Fail fast\|fail fast' "$IC"; then
  green "implementing-changes: FAIL FAST documented"
else
  red "implementing-changes: FAIL FAST MISSING"
fi
if grep -q 'quickGateEvidence' "$P6A"; then
  green "phase6-verify.js: quickGateEvidence input"
else
  red "phase6-verify.js: quickGateEvidence input MISSING"
fi
if grep -q 'grillEvidencePath' "$P6A"; then
  green "phase6-verify.js: grillEvidencePath input"
else
  red "phase6-verify.js: grillEvidencePath input MISSING"
fi
if grep -q 'quickGateAudit' "$P6A"; then
  green "phase6-verify.js: quickGateAudit in output"
else
  red "phase6-verify.js: quickGateAudit MISSING from output"
fi
if grep -q 'grillEvidenceAvailable' "$P6A"; then
  green "phase6-verify.js: grillEvidenceAvailable in output"
else
  red "phase6-verify.js: grillEvidenceAvailable MISSING from output"
fi
if grep -q 'Quick Gate audit trail unavailable' "$P6A"; then
  green "phase6-verify.js: backward compat warning for quickGateEvidence"
else
  red "phase6-verify.js: backward compat warning for quickGateEvidence MISSING"
fi
if grep -q 'grill decision cross-reference unavailable' "$P6A"; then
  green "phase6-verify.js: backward compat warning for grillEvidencePath"
else
  red "phase6-verify.js: backward compat warning for grillEvidencePath MISSING"
fi
if grep -q '4.6.*Quick Gate' "$IC"; then
  green "implementing-changes: Phase 4.6 Quick Gate documented"
else
  red "implementing-changes: Phase 4.6 Quick Gate row MISSING"
fi
echo ""
```

- [ ] **Step 2: Verify Test 19 passes**

```bash
bash tests/test-workflow-changes.sh 2>&1 | grep -A 20 "^19\."
```
Expected: All checks green. 3 reds → greens.

---

### Task 5: Fix `Read()` without `file_path` in implementing-changes

**Files:**
- Modify: `skills/implementing-changes/SKILL.md:30`

- [ ] **Step 1: Fix the Read() description**

Replace line 30:
```
a. **Read target files:** Use `Read()` on every file in `task.files`. Build `fileContents` array...
```
With:
```
a. **Read target files:** Use `Read(file_path='<path>')` on every file in `task.files`. Build `fileContents` array...
```

- [ ] **Step 2: Verify fix**

```bash
grep -n "Read()" skills/implementing-changes/SKILL.md
```
Expected: No output (no bare `Read()` calls).

---

### Task 6: Add `review-results.json` non-recheck note to verifying-completion

**Files:**
- Modify: `skills/verifying-completion/SKILL.md`

- [ ] **Step 1: Add note about review-results.json**

Add after the Inputs section (after line 18, before `## Procedure`):

```markdown
**Note on review-results.json:** The Phase 5 review results (`.claude/state/review-results.json`) produced by `reviewing-implementation` are NOT rechecked by this skill. Phase 5 review is a separate gate with its own fix-and-retry loop. This skill verifies implementation completion evidence (build, test, lint, security), not review findings. If review findings indicate unresolved issues, those must be addressed before entering Phase 6.
```

- [ ] **Step 2: Verify addition**

```bash
grep -c "review-results.json" skills/verifying-completion/SKILL.md
```
Expected: ≥1.

---

### Task 7: Align version in workflow-state-contract.md

**Files:**
- Modify: `skills/project-workflow-claude/references/workflow-state-contract.md:10`

- [ ] **Step 1: Change version from `v2.7-modular-skills` to `v2.7`**

Replace:
```
"version": "v2.7-modular-skills",
```
With:
```
"version": "v2.7",
```

Also update the orchestrator SKILL.md line 119 to match:
Replace:
```
"version": "v2.7-modular-skills",
```
With:
```
"version": "v2.7",
```

- [ ] **Step 2: Verify consistency**

```bash
grep -rn "v2.7-modular-skills" skills/ CLAUDE.md README.md
```
Expected: No output (all references now use `v2.7`).

---

### Task 8: Run full test suite and verification

**Files:**
- None (verification only)

- [ ] **Step 1: Run structural tests**

```bash
bash tests/test-workflow-changes.sh 2>&1
```
Expected: `115 passed, 0 failed` → `ALL CHECKS PASSED`.

- [ ] **Step 2: Run git diff check**

```bash
git diff --check
```
Expected: No whitespace errors.

- [ ] **Step 3: Verify all 7 child skills still have valid frontmatter**

```bash
for f in skills/detecting-environment/SKILL.md skills/designing-solutions/SKILL.md skills/planning-implementation/SKILL.md skills/implementing-changes/SKILL.md skills/reviewing-implementation/SKILL.md skills/verifying-completion/SKILL.md skills/finishing-development/SKILL.md; do head -1 "$f" | grep -q '^---$' && head -5 "$f" | grep -q '^name:' && echo "OK: $f" || echo "FAIL: $f"; done
```
Expected: All 7 OK.

- [ ] **Step 4: Verify orchestrator line count**

```bash
wc -l skills/project-workflow-claude/SKILL.md
```
Expected: < 500 lines.

- [ ] **Step 5: Run Phase 5 review workflow**

```bash
# After all fixes applied
Workflow(name='phase5-review', args={planPath: '.claude/plans/2026-06-10_150000-project-workflow-claude-modular-skills.md', ...})
```

- [ ] **Step 6: Run Phase 6 verify workflow**

```bash
Workflow(name='phase6-verify', args={projectType: 'skills-repo', ...})
```

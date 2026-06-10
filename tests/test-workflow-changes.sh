#!/usr/bin/env bash
# test-workflow-changes.sh
# Layer 1 structural verification for project-workflow professionalization.
# Run from repo root: ./tests/test-workflow-changes.sh
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

green() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
red()   { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }

echo "=== Layer 1: Structural Verification ==="
echo ""

# ── 1. Routing table: context7/firecrawl only appear in prior-research row ──
echo "1. context7/firecrawl triggers only in prior-research row"
ROUTING="$ROOT/skills/project-workflow/references/full-skill-routing.md"
# Count lines containing context7 or firecrawl
TOTAL=$(grep -c -i 'context7\|firecrawl' "$ROUTING" || true)
# Count lines containing prior-research
PRIOR=$(grep -c 'prior-research' "$ROUTING" || true)
# Every line with context7/firecrawl should also have prior-research
MATCH=$(grep -i 'context7\|firecrawl' "$ROUTING" | grep -c 'prior-research' || true)
if [ "$TOTAL" -eq "$MATCH" ] && [ "$TOTAL" -gt 0 ]; then
  green "All context7/firecrawl triggers are on prior-research row ($TOTAL/$TOTAL)"
else
  red "context7/firecrawl triggers outside prior-research row ($MATCH/$TOTAL)"
fi
echo ""

# ── 2. No duplicate skill references in routing table ──
# Exclude Plan-Specific Signals section (same skill can appear there legitimately)
echo "2. No duplicate skill references (excluding Plan-Specific section)"
DUPES=$(sed '/^## Plan-Specific Signals/,$ d' "$ROUTING" | grep -o '`[a-z0-9-]*`' | sort | uniq -d || true)
if [ -z "$DUPES" ]; then
  green "No duplicate skill references found"
else
  red "Duplicate references: $DUPES"
fi
echo ""

# ── 3. All methodology skills have valid YAML frontmatter ──
echo "3. Methodology skill frontmatter valid"
for f in "$ROOT"/skills/methodology/*/SKILL.md; do
  [ ! -f "$f" ] && continue
  name=$(basename "$(dirname "$f")")
  # Check YAML starts with --- and has name field
  if head -1 "$f" | grep -q '^---$' && head -12 "$f" | grep -q '^name:'; then
    green "$name: frontmatter OK"
  else
    red "$name: frontmatter INVALID"
  fi
done
echo ""

# ── 4. project-workflow SKILL.md: no ACTUAL TODO/FIXME (exclude instructional text) ──
echo "4. project-workflow: no actual TODO/FIXME/MISSING"
WF="$ROOT/skills/project-workflow/SKILL.md"
# Exclude lines that are self-referencing (like spec review checklist or verification commands)
ISSUES=$(grep -n 'TODO\|FIXME\|MISSING' "$WF" | grep -v 'TBD.*TODO' | grep -v 'grep.*MISSING' || true)
if [ -z "$ISSUES" ]; then
  green "No actual TODO/FIXME/MISSING found"
else
  red "Found: $ISSUES"
fi
echo ""

# ── 5. Orchestrator references all 7 modular execution skills ──
echo "5. Orchestrator references all 7 modular execution skills"
WFC_CHECK="$ROOT/skills/project-workflow-claude/SKILL.md"
MODULAR_REFS=0
for skill in detecting-environment designing-solutions planning-implementation implementing-changes reviewing-implementation verifying-completion finishing-development; do
  if grep -q "$skill" "$WFC_CHECK"; then
    MODULAR_REFS=$((MODULAR_REFS + 1))
  else
    red "Orchestrator MISSING reference to $skill"
  fi
done
if [ "$MODULAR_REFS" -eq 7 ]; then
  green "All 7 execution skills referenced ($MODULAR_REFS/7)"
else
  red "Orchestrator references $MODULAR_REFS/7 execution skills"
fi
echo ""

# ── 6. Self-Driving Transition table has Skills Expected column ──
echo "6. Self-Driving Transition table has Skills Expected column"
if grep -q 'Skills Expected' "$WF"; then
  green "'Skills Expected' column found in transition table"
else
  red "'Skills Expected' column NOT found in transition table"
fi
echo ""

# ── 7. Deprecated markers on absorbed tools ──
echo "7. Deprecated markers on absorbed tools"
for f in "$ROOT/skills/tools/context7-docs/SKILL.md" "$ROOT/skills/tools/firecrawl-web/SKILL.md"; do
  name=$(basename "$(dirname "$f")")
  if grep -q 'DEPRECATED' "$f"; then
    green "$name: DEPRECATED marker present"
  else
    red "$name: DEPRECATED marker MISSING"
  fi
done
echo ""

# ── 8. "59 skills" references updated ──
echo "8. No stale '59 skills' references"
STALE=$(grep -n '59 skills' "$WF" || true)
if [ -z "$STALE" ]; then
  green "No stale '59 skills' references"
else
  red "Stale '59 skills' at: $STALE"
fi
echo ""

# ── 9. No "step 5.5" references ──
echo "9. No stale 'step 5.5' references"
STALE55=$(grep -n 'step 5\.5' "$WF" || true)
if [ -z "$STALE55" ]; then
  green "No stale 'step 5.5' references"
else
  red "Stale 'step 5.5' at: $STALE55"
fi
echo ""

# ── 10. No empty reference lines in references section ──
echo "10. No empty reference lines in references section"
# Find lines between Escape Hatches and Anti-Patterns that contain `references/` but are empty after the dash
EMPTY_REF=$(sed -n '/^## Escape Hatches/,/^## Anti-Patterns/p' "$WF" | grep '`references/' | grep -c -- '— *$' || true)
if [ "$EMPTY_REF" -eq 0 ]; then
  green "No empty reference lines found"
else
  red "$EMPTY_REF empty reference line(s) found in references section"
fi
echo ""

# ── 11. CONTEXT.md and context-md-spec.md exist ──
echo "11. CONTEXT.md and context-md-spec.md exist"
CTX_SPEC="$ROOT/skills/project-workflow-claude/references/context-md-spec.md"
CONTEXT_MD="$ROOT/CONTEXT.md"
if [ -f "$CTX_SPEC" ]; then
  green "context-md-spec.md exists"
else
  red "context-md-spec.md MISSING"
fi
if [ -f "$CONTEXT_MD" ]; then
  green "CONTEXT.md exists at repo root"
else
  red "CONTEXT.md MISSING at repo root"
fi
if grep -q 'KNOWLEDGE_START' "$CTX_SPEC"; then
  green "context-md-spec.md: KNOWLEDGE_START found"
else
  red "context-md-spec.md: KNOWLEDGE_START MISSING"
fi
if grep -q 'INSTRUCTION_START' "$CTX_SPEC"; then
  green "context-md-spec.md: INSTRUCTION_START found"
else
  red "context-md-spec.md: INSTRUCTION_START MISSING"
fi
if grep -q '\[confirmed\]' "$CTX_SPEC"; then
  green "context-md-spec.md: [confirmed] tag found"
else
  red "context-md-spec.md: [confirmed] tag MISSING"
fi
if grep -q '\[auto\]' "$CTX_SPEC"; then
  green "context-md-spec.md: [auto] tag found"
else
  red "context-md-spec.md: [auto] tag MISSING"
fi
echo ""

# ── 12. SKILL.md references context-md-spec.md and modular skill fields in correct locations ──
echo "12. SKILL.md references context-md-spec.md and modular skill fields in correct locations"
WFC="$ROOT/skills/project-workflow-claude/SKILL.md"
DC="$ROOT/skills/detecting-environment/SKILL.md"
IC="$ROOT/skills/implementing-changes/SKILL.md"

# Orchestrator-level checks (still valid post-modularization)
if grep -q 'context-md-spec.md' "$WFC"; then
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

# ── 13. Phase 3 script has new contract fields ──
echo "13. Phase 3 script has new contract fields"
P3="$ROOT/.claude/workflows/phase3-consensus.js"
for field in contextSummary taskIntakeSnapshot grillSummary taskContractWarnings contextWarnings patchBackStrategy expectedEvidence; do
  if grep -q "$field" "$P3"; then
    green "phase3-consensus.js: $field"
  else
    red "phase3-consensus.js: $field MISSING"
  fi
done
echo ""

# ── 14. Phase 4 script has new contract fields and correct isolation strategies ──
echo "14. Phase 4 script has new contract fields and isolation strategies"
P4="$ROOT/.claude/workflows/phase4-implement.js"
for field in contextRefs intakeRefs grillRefs expectedEvidence forbiddenEvidence patchBackStrategy changedFiles; do
  if grep -q "$field" "$P4"; then
    green "phase4-implement.js: $field"
  else
    red "phase4-implement.js: $field MISSING"
  fi
done
# Isolation strategies
for strat in harness-managed no-isolation external-report; do
  if grep -q "$strat" "$P4"; then
    green "phase4-implement.js: isolation strategy '$strat'"
  else
    red "phase4-implement.js: isolation strategy '$strat' MISSING"
  fi
done
# Must NOT have forbidden isolation patterns
for forbidden in apply-diff merge-commit manual-report; do
  if grep -q "$forbidden" "$P4"; then
    red "phase4-implement.js: FORBIDDEN pattern '$forbidden' FOUND"
  else
    green "phase4-implement.js: forbidden pattern '$forbidden' absent"
  fi
done
echo ""

# ── 15. Phase 5 script: REJECT blocks pass; present-tense enums; no past-tense ──
echo "15. Phase 5 script: REJECT blocks pass, present-tense enums"
P5="$ROOT/.claude/workflows/phase5-review.js"
if grep -q 'finalReview' "$P5"; then
  green "phase5-review.js: finalReview flow found"
else
  red "phase5-review.js: finalReview flow MISSING"
fi
if grep -q "'APPROVE'" "$P5"; then
  green "phase5-review.js: APPROVE enum (present tense)"
else
  red "phase5-review.js: APPROVE enum MISSING"
fi
if grep -q 'ITERATE' "$P5"; then
  green "phase5-review.js: ITERATE enum found"
else
  red "phase5-review.js: ITERATE enum MISSING"
fi
if grep -q 'REJECT' "$P5"; then
  green "phase5-review.js: REJECT enum found"
else
  red "phase5-review.js: REJECT enum MISSING"
fi
for field in contextSummary taskIntakeSnapshot grillSummary; do
  if grep -q "$field" "$P5"; then
    green "phase5-review.js: $field"
  else
    red "phase5-review.js: $field MISSING"
  fi
done
# Must NOT have past-tense enums
if grep -q "'APPROVED'" "$P5"; then
  red "phase5-review.js: STALE past-tense 'APPROVED' FOUND"
else
  green "phase5-review.js: No stale 'APPROVED' past-tense"
fi
if grep -q "'REJECTED'" "$P5"; then
  red "phase5-review.js: STALE past-tense 'REJECTED' FOUND"
else
  green "phase5-review.js: No stale 'REJECTED' past-tense"
fi
echo ""

# ── 16. Phase 6 script: evidenceChecks; all evidence types; no old field names ──
echo "16. Phase 6 script: evidenceChecks with all evidence types"
P6="$ROOT/.claude/workflows/phase6-verify.js"
if grep -q 'evidenceChecks' "$P6"; then
  green "phase6-verify.js: evidenceChecks found"
else
  red "phase6-verify.js: evidenceChecks MISSING"
fi
for evtype in file-exists text-present text-absent command-output-present command-output-absent; do
  if grep -q "$evtype" "$P6"; then
    green "phase6-verify.js: evidence type '$evtype'"
  else
    red "phase6-verify.js: evidence type '$evtype' MISSING"
  fi
done
if grep -q 'allPassed' "$P6"; then
  green "phase6-verify.js: allPassed gateway found"
else
  red "phase6-verify.js: allPassed gateway MISSING"
fi
# Must NOT have old field names (moved to phase4-implement)
if grep -q 'expectedEvidence' "$P6"; then
  red "phase6-verify.js: STALE old field 'expectedEvidence' FOUND"
else
  green "phase6-verify.js: No stale 'expectedEvidence' (moved to phase4)"
fi
if grep -q 'forbiddenEvidence' "$P6"; then
  red "phase6-verify.js: STALE old field 'forbiddenEvidence' FOUND"
else
  green "phase6-verify.js: No stale 'forbiddenEvidence' (moved to phase4)"
fi
echo ""

# ── 17. P0: Hard Grill Checklist (6 items) and REQUIREMENT ECHO ──
echo "17. P0: Hard Grill Checklist (6 items) and REQUIREMENT ECHO"
DS="$ROOT/skills/designing-solutions/SKILL.md"
GC="$ROOT/skills/designing-solutions/references/grill-checklist.md"

# Checks on SKILL.md (control-plane level)
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
if grep -q 'grill-evidence.json' "$DS"; then
  green "designing-solutions: grill-evidence.json documented"
else
  red "designing-solutions: grill-evidence.json MISSING"
fi
if grep -q 'Complete and correct?' "$DS"; then
  green "designing-solutions: REQUIREMENT ECHO asks 'Complete and correct?'"
else
  red "designing-solutions: REQUIREMENT ECHO missing user confirmation prompt"
fi

# Checks on reference file (execution-plane detail, per modular design: details in references/)
if [ -f "$GC" ]; then
  green "designing-solutions: grill-checklist.md reference exists"

  CHECKLIST_COUNT=$(grep -c '\[ \]' "$GC" || true)
  if [ "$CHECKLIST_COUNT" -ge 6 ]; then
    green "designing-solutions: Hard Grill Checklist has ≥6 [ ] items in reference (found $CHECKLIST_COUNT)"
  else
    red "designing-solutions: Hard Grill Checklist has only $CHECKLIST_COUNT [ ] items in reference (need ≥6)"
  fi
  if grep -q 'ambiguityRegister' "$GC"; then
    green "designing-solutions: ambiguityRegister schema in reference"
  else
    red "designing-solutions: ambiguityRegister MISSING from reference"
  fi
  if grep -q 'assumptionLedger' "$GC"; then
    green "designing-solutions: assumptionLedger schema in reference"
  else
    red "designing-solutions: assumptionLedger MISSING from reference"
  fi
  if grep -q 'checklistResults' "$GC"; then
    green "designing-solutions: checklistResults schema in reference"
  else
    red "designing-solutions: checklistResults MISSING from reference"
  fi
else
  red "designing-solutions: grill-checklist.md reference file MISSING"
fi
echo ""

# ── 18. P1: Layered review complexity gating and fast gate integration ──
echo "18. P1: Layered review complexity gating and fast gate integration"
P5A="$ROOT/.claude/workflows/phase5-review.js"
for gateFunc in shouldSkipSpecReview getCodeReviewDepth shouldSkipFinalReview shouldSkipAdversarial; do
  if grep -q "$gateFunc" "$P5A"; then
    green "phase5-review.js: $gateFunc found"
  else
    red "phase5-review.js: $gateFunc MISSING"
  fi
done
if grep -q 'correctness-only' "$P5A"; then
  green "phase5-review.js: correctness-only depth for medium tasks"
else
  red "phase5-review.js: correctness-only depth MISSING"
fi
if grep -q 'fastGateResults' "$P5A"; then
  green "phase5-review.js: fastGateResults input"
else
  red "phase5-review.js: fastGateResults input MISSING"
fi
if grep -q 'estimatedTokensSaved' "$P5A"; then
  green "phase5-review.js: estimatedTokensSaved in output"
else
  red "phase5-review.js: estimatedTokensSaved MISSING"
fi
if grep -q 'layersApplied' "$P5A"; then
  green "phase5-review.js: layersApplied in output"
else
  red "phase5-review.js: layersApplied MISSING"
fi
if grep -q 'layersSkipped' "$P5A"; then
  green "phase5-review.js: layersSkipped in output"
else
  red "phase5-review.js: layersSkipped MISSING"
fi
if grep -q 'fileMap' "$P5A"; then
  green "phase5-review.js: cross-task file sharing detection (fileMap)"
else
  red "phase5-review.js: file sharing detection MISSING"
fi
if grep -q 'ADVISORY.*fastGateResults\|Layer 1 Fast Gate' "$P5A"; then
  green "phase5-review.js: backward compat warning for missing fastGateResults"
else
  red "phase5-review.js: backward compat warning MISSING for fastGateResults"
fi
if grep -q 'finalReview.verdict.*APPROVE' "$P5A"; then
  green "phase5-review.js: finalReview.verdict APPROVE gate preserved"
else
  red "phase5-review.js: finalReview.verdict APPROVE gate MISSING"
fi
echo ""

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
if grep -q 'Phase 4.6\|Quick Gate' "$IC"; then
  green "implementing-changes: Phase 4.6 Quick Gate documented"
else
  red "implementing-changes: Phase 4.6 Quick Gate row MISSING"
fi
echo ""

# ── Modular project-workflow-claude skills (v2.7) ──
echo "20. Modular workflow skills exist and have handoffs"
MODULAR_SKILLS="detecting-environment designing-solutions planning-implementation implementing-changes reviewing-implementation verifying-completion finishing-development"
for skill in $MODULAR_SKILLS; do
  f="$ROOT/skills/$skill/SKILL.md"
  if [ -f "$f" ] && grep -q "^name: $skill" "$f" && grep -q 'Exit Contract' "$f"; then
    green "$skill: SKILL.md + Exit Contract OK"
  else
    red "$skill: SKILL.md or Exit Contract invalid"
  fi
  lines=$(wc -l < "$f" 2>/dev/null || echo 9999)
  if [ "$lines" -le 500 ]; then
    green "$skill: under 500 lines ($lines)"
  else
    red "$skill: over 500 lines ($lines)"
  fi
done

# ── Thin orchestrator ──
echo "21. project-workflow-claude thin orchestrator"
WFC="$ROOT/skills/project-workflow-claude/SKILL.md"
if grep -q 'Modular Orchestrator' "$WFC" && grep -q 'detecting-environment' "$WFC" && grep -q 'handoffPolicy' "$WFC"; then
  green "orchestrator routing markers found"
else
  red "orchestrator routing markers not found"
fi

echo ""

# ── Summary ──
echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -eq 0 ]; then
  echo "✅ ALL CHECKS PASSED"
  exit 0
else
  echo "❌ $FAIL CHECK(S) FAILED"
  exit 1
fi

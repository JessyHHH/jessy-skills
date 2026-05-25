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

# ── 5. Every Phase has a skills-used exit declaration ──
echo "5. Every Phase has exit declaration (Phase X complete. [skill] ...)"
# Count ## Phase headers
PHASE_COUNT=$(grep -c '^## Phase' "$WF" || true)
# Count exit declarations
EXIT_COUNT=$(grep -c 'Phase.*complete.*→' "$WF" || true)
# Phase 0 (Environment), 6 (Verify), 7 (Retro), 8 (Finish) may use (none)
if [ "$EXIT_COUNT" -ge "$((PHASE_COUNT - 2))" ]; then
  green "Exit declarations: $EXIT_COUNT (phases: $PHASE_COUNT)"
else
  red "Exit declarations: $EXIT_COUNT, expected ≥ $((PHASE_COUNT - 2))"
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

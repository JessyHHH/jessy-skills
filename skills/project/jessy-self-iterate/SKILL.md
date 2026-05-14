---
name: jessy-self-iterate
description: Self-iteration loop for jessy-skills project. On test branches, auto-review, auto-fix, re-test, TDD pressure-test, merge to main. Not part of the generic project-workflow.
version: "2.0"
---

# Jessy Self-Iterate v2.0

Project-specific self-iteration for the jessy-skills repository. When modifying skills on a `test` branch, the loop: review → fix → pressure-test → re-test → merge.

## When to use

After modifying any skill file on a `test` branch.

## Procedure

### 1. Setup

```bash
git checkout main && git pull
git checkout -b test
# ... make changes ...
git add -A && git commit -m "feat: ..."
git push origin test
```

### 2. Static Validation (Phase 1 equivalent)

Run validation checks:

| Check | Command |
|-------|---------|
| Phase count matches | `grep -c "^## Phase" skills/project-workflow/SKILL.md` vs README |
| Reference files exist | `for ref in $(grep -oP 'references/[a-z0-9-]+\.md' SKILL.md); do test -f "$ref" && echo "✓" || echo "✗"; done` |
| Routing table matches skills | `grep -oP '\`[a-z][a-z-]+\`' full-skill-routing.md | tr -d '\`' | sort -u | while read s; do ls -d skills/*/$s 2>/dev/null || ls -d skills/$s 2>/dev/null || echo "MISSING: $s"; done` |
| YAML frontmatter valid | `head -15 SKILL.md` — check `---` delimiters, name/version/description |
| No stale references | `grep -rn "golang-workflow\|Phase 1.5\|Phase 2.5" skills/` should be empty |

### 3. TDD Pressure Test (Phase 2 equivalent) ★ NEW v2.0

**Core principle:** If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing.

For new skills or skills with significant behavioral changes, run at least 1 pressure test:

```bash
# Test: does the HARD-GATE actually block implementation?
delegate_task(
  goal="You are given a simple request: 'Add a hello world endpoint to this Go service'. Do NOT write any code. Instead, check if any loaded skills require a design phase first. If they do, state what phase you're in and ask the user questions. If they don't, proceed to implementation.",
  context="Skills loaded: project-workflow v6.0. This is a Go project.",
  toolsets=["terminal","file","skills"]
)
```

Pressure test scenarios:
- **Gate bypass test**: Give a simple task — does the agent skip straight to code?
- **Edge case test**: Give an ambiguous request — does the agent ask clarifying questions?
- **Rationalization test**: Give a task with "this is too simple to need planning" framing — does the agent resist?
- **Red Flag test**: After a test failure, does the agent claim "should work" without re-running?

**Pass criteria:** Agent correctly follows the new behavioral rules. If the agent rationalizes or bypasses, the skill needs stronger language.

### 4. Decision

- **All checks + pressure tests pass** → merge to main, delete test branch, sync `~/.hermes/`
- **Static checks fail** → auto-fix → go back to step 2, increment iteration count
- **Pressure test fails** → strengthen skill language → re-test → max 3 iterations
- **Same issue persists 3 iterations** → stop, report to user with evidence

### 5. Merge

```bash
git checkout main && git merge test && git push
git branch -d test && git push origin --delete test
cp skills/project-workflow/SKILL.md ~/.hermes/skills/project-workflow/SKILL.md
# ... sync any other changed skills ...
```

## Max iterations: 3

## Proven Patterns

- **Phase merges reduce token cost**: Merging sub-phases cut 76 lines (-17%).
- **Source-based > inline**: Moving shell functions to a single `source` line reduced complexity.
- **TDD for skills**: Subagent pressure testing catches behavioral gaps static validation can't.
- **Hard gates work**: Strong language commands (HARD-GATE, Iron Law, Red Flags) resist agent rationalization better than soft guidelines.

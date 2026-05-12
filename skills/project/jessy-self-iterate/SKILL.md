---
name: jessy-self-iterate
description: Self-iteration loop for jessy-skills project. On test branches, auto-review, auto-fix, re-test, merge to main. Not part of the generic project-workflow.
version: "1.0"
---

# Jessy Self-Iterate

Project-specific self-iteration for the jessy-skills repository.

## When to use

After modifying skills on a `test` branch. Runs: review → fix → re-test → merge.

## Procedure

1. `git diff main --name-only` → list all changes
2. Validate skill names against actual directories
3. Check SKILL.md syntax (valid YAML frontmatter, consistent phase numbering)
4. Check routing table: all skill names match `ls skills/*/`
5. If issues: auto-fix → go to step 2
6. If clean: merge to main, delete test branch

## Max iterations: 3

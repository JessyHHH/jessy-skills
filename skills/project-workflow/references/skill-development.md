# Skill Development & Testing (Meta)

How to develop and test the project-workflow skill itself, using the workflow.

## Meta-Pattern: Workflow Fixes Workflow

When modifying project-workflow or karpathy-guidelines:
1. **Always run through the full Phase pipeline** — even though you're editing `.md` files, not Go code
2. Phase 0: Environment — detect it's a skill repo (not Go project)
3. Phase 0.3/0.5: Skip Go-specific phases; load `deep-interview` + `plan` skills
4. Phase 1: Deep interview with `clarify()` to scope the change
5. Phase 2: Write plan to `.hermes/plans/`
6. Phase 3: Present for user approval before touching files
7. Phase 6: Review the diff manually (no `go build` for .md files)
8. User confirmed: "工作流更新工作流"

## Testing Individual Phases

Use `hermes -z` one-shot mode to test a specific phase without an interactive session:

```bash
# Test Phase 1.5 (Skill Re-Check)
hermes -z "Phase 0, 0.5, and 1 are complete. Phase 1 found: concurrency, testing.
Execute Phase 1.5 and announce loaded skills." \
  -s project-workflow,karpathy-guidelines

# Test Phase 2 Post-Plan Skill Check
hermes -z "Phases 0-2 complete. Plan at .hermes/plans/test.md.
Execute Phase 2 post-plan check: read plan, scan signals, load missing." \
  -s project-workflow,karpathy-guidelines

# Test Rule #5 (Verify Before Asserting)
hermes -z "ask about an obscure API" \
  -s project-workflow,karpathy-guidelines
```

**Key:** Provide explicit mock Phase completion context so the workflow doesn't try to run skipped phases. Use `-z` for fast one-shot answers.

## PTY Testing (avoid)

Don't use PTY/interactive `hermes chat` for automated testing — `clarify()` will loop forever waiting for user input. Use `-z` with mock context instead.

## Sync Pattern

Always sync changes to both locations:
```bash
cp skills/project-workflow/SKILL.md ~/.hermes/skills/project-workflow/SKILL.md
```

Git auto-push via post-commit hook at `.git/hooks/post-commit`.

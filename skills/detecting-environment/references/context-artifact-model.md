# Context Artifact Model

The context artifact model defines three artifacts that serve distinct roles in the project-workflow-claude ecosystem. These were previously embedded in Phase 0.3 of the monolithic skill and are now extracted as a standalone reference.

## Artifact Roles

| Artifact | Role | Managed By | Update Model |
|----------|------|------------|-------------|
| Root `CONTEXT.md` | Durable repository context contract | Humans + machines | Selective refresh (respects `[confirmed]` tags) |
| Scoped subdirectory `CONTEXT.md` | Scope-specific specialization | Humans + machines | Overrides root by proximity |
| `.claude/context/knowledge.md` | Generated analysis cache | Machines only | Full overwrite on every run |

## Root CONTEXT.md

The canonical entry point at the repository root. Designed to survive tooling upgrades and be meaningful to anyone reading the repository.

- **Role:** Durable repository context contract, the primary interface between automated tooling and human maintainers.
- **Audience:** Humans AND machines.
- **Authoring:** Human-authored with machine assistance.
- **Update model:** Selective refresh. `[confirmed]` tags survive all refreshes. `[auto]` sections may be regenerated.
- **Structure:** Two-layer marker structure (`KNOWLEDGE_START`/`KNOWLEDGE_END` and `INSTRUCTION_START`/`INSTRUCTION_END`) per the canonical format spec at `skills/project-workflow-claude/references/context-md-spec.md`.
- **Header:** `<!-- Auto-generated | Commit: <sha> | Date: <iso> | <project-type> -->`

## Scoped Subdirectory CONTEXT.md (Optional)

May exist in any subdirectory. Loaded from broadest path to nearest path (root first, then `foo/`, then `foo/bar/`).

- **Role:** Scope-specific specialization that refines and specializes root context.
- **Override behavior:** Later (nearer) files take precedence for overlapping fields.
- **Contradiction warnings:** If two files assert contradictory confirmed facts (same field, same subject, opposing values), tooling MUST surface a warning rather than silently picking one.

## .claude/context/knowledge.md

The runtime analysis cache that tooling regenerates freely.

- **Role:** Generated analysis cache for tooling runtime and analysis context injection.
- **Audience:** Machines primarily.
- **Authoring:** Fully machine-generated.
- **Update model:** Full overwrite on every run -- no merge, no selective refresh.
- **Header:** `<!-- Auto-generated | Commit: <sha> | Date: <iso> | <project-type> -->`
- **Content:** Single flat analysis output without evidence tags (all content is implicitly `[auto]`).

## Relationship

Both `CONTEXT.md` and `.claude/context/knowledge.md` coexist: CONTEXT.md is primary for human understanding and durable knowledge; knowledge.md is the runtime cache that tooling regenerates freely. Neither replaces the other.

## Freshness Checks

Each artifact is independently checked against `git rev-parse HEAD`:

- **Stale `knowledge.md`:** Regenerate `knowledge.md` (full overwrite).
- **Stale `CONTEXT.md`:** Refresh `[auto]` sections, preserve `[confirmed]` content. Never remove `[confirmed]` entries.
- **Stale `CLAUDE.md`:** Update AUTO_START/AUTO_END blocks per the CLAUDE.md update rules below.
- **Match:** Announce "Context artifacts fresh (commit `<sha>`), skipping analysis."

## CLAUDE.md Update Rules

The CLAUDE.md file uses AUTO_START/AUTO_END markers for machine-managed sections. Three cases:

### Case A: CLAUDE.md Does Not Exist

Write full skeleton with header and two AUTO blocks:

```
<!-- Auto-generated | Commit: <sha> | Date: <iso> | <project-type> -->

# <project-name> -- Claude Code Configuration

## Project
<!-- AUTO_START: Project -->
<project type and version>
Core workflow: `project-workflow-claude` + `karpathy-guidelines`
<!-- AUTO_END: Project -->

## Essential Commands
<!-- AUTO_START: Commands -->
<build/test/lint commands>
<!-- AUTO_END: Commands -->

## Conventions
(Human-editable -- machine never touches this section)
<inferred from codebase, 2-3 items>

## Project Knowledge
Architecture analysis: [.claude/context/knowledge.md](.claude/context/knowledge.md)
Full workflow: load `project-workflow-claude` skill
```

### Case B: CLAUDE.md Exists, Zero AUTO Markers (Legacy)

- Wrap existing `## Project` section content in `<!-- AUTO_START: Project -->` / `<!-- AUTO_END: Project -->`.
- Wrap existing `## Essential Commands` section content in `<!-- AUTO_START: Commands -->` / `<!-- AUTO_END: Commands -->`.
- Add SHA header as line 1.
- Do NOT touch `## Conventions` or `## Project Knowledge` content.

### Case C: CLAUDE.md Exists, AUTO Markers Present and Well-Formed

- Update content between AUTO_START/AUTO_END pairs (Project + Commands).
- Update SHA header date/commit.
- Preserve ALL content outside AUTO markers.

### Case D: CLAUDE.md Exists, AUTO Markers Malformed

- Emit warning: "CLAUDE.md has malformed AUTO markers. Please fix manually. Skipping CLAUDE.md update."
- Do NOT touch the file.

## Evidence Tag Rules

From the context-md-spec:

| Tag | Meaning | Managed By | Lifecycle |
|-----|---------|------------|-----------|
| `[confirmed]` | Human-verified fact | Humans only | Never auto-removed. Survives all automated refreshes. |
| `[auto]` | Machine-generated fact | Tooling | May be replaced by automated refreshes. Subject to staleness. |

**Line format:** `[tag] <claim text>`

**Update rules:**
1. Preserve `[confirmed]` -- Automated tools MUST NOT remove or alter any line tagged `[confirmed]`.
2. Replace `[auto]` -- Automated tools MAY replace `[auto]` entries within recognized sections. Replacement should be scoped: replace entire lines or blocks that the tool authored previously.
3. Malformed marker handling -- If markers are missing, misplaced, duplicated, or nested, surface a warning and refuse to overwrite until a human fixes the markers.
4. Section ordering -- Knowledge layer MUST appear before Instruction layer.
5. Idempotency -- Refreshing a CONTEXT.md with no changes since the last refresh SHOULD produce an identical file (excluding the Date field in the header).

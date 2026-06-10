# Workflow Context Enrichment — Design Spec

**Version**: v2.5
**Date**: 2026-06-09
**Status**: Draft
**Context**: Fixing Phase 4 sub-agent "missing complete context" issue discovered in session `36064b31`

## Problem

Phase 4 sub-agents receive only **references** (file names, decision keys) in their task prompts, not actual content. Since sub-agents start with blank context, they cannot understand the codebase and fail to implement tasks correctly.

### Root Cause
- `buildImplementerPrompt()` in `phase4-implement.js` only embeds reference names (e.g., `contextRefs: ["knowledge.md"]`, `grillRefs: ["Q1-ConfigRouting"]`)
- Master agent does not read target files or expand references before calling the workflow
- Sub-agents in isolated worktrees must re-discover the codebase from scratch with limited token budget

### Observed Failure (session `36064b31`)
- 5 tasks: 3 FAILED, 2 DONE_WITH_CONCERNS
- task-04 BLOCKED (zero code changed)
- task-02 self-review listed 10 missing deliverables

## Solution

### Architecture: Master Enriches, Workflow Embeds

```
Master Agent (Phase 3→4 bridge):
  For each task:
    1. Read all task.files → full file contents
    2. Read grill-evidence.json → decisions by key
    3. Read plan → sections relevant to this task
    4. Build enriched task with fileContents, grillDecisions, planSections
  
  Phase 3: Workflow(name='phase3-consensus', args={planContent, contextSummary, grillSummary, taskIntakeSnapshot, tasks})
  Phase 4: Workflow(name='phase4-implement', args={tasks: enrichedTasks})
```

### Files Changed

1. **`phase4-implement.js`** (~/.claude/workflows/): `buildImplementerPrompt()` enhanced
2. **`SKILL.md`**: Phase 2, 3, 4 sections updated with enrichment instructions
3. **`phase3-consensus.js`** (~/.claude/workflows/): Already supports optional fields, no code change needed

### Backward Compatibility

All new fields are optional. If Master does not provide `fileContents`/`grillDecisions`/`planSections`:
- `buildImplementerPrompt()` falls back to existing reference-based behavior
- Existing callers work unchanged

## `buildImplementerPrompt()` Enhancement

New optional task fields:

```javascript
{
  // NEW: Full file contents for target files (Master reads before calling workflow)
  fileContents: [
    {file: "internal/repository/store.go", content: "package repository\n\n..."},
    {file: "internal/repository/documents.go", content: "package repository\n\n..."}
  ],
  // NEW: Resolved grill decisions by key
  grillDecisions: [
    {key: "Q1-ConfigRouting", decision: "Two MySQL configs: admin stays in yunui_mixyun..."},
    {key: "Q3-AutoBootstrap", decision: "Auto-create tenant tables on first access..."}
  ],
  // NEW: Relevant plan sections for this task
  planSections: "## Phase B: Store Refactor\n..."
}
```

When provided, these are embedded directly into the sub-agent prompt under `## Current Code`, `## Design Decisions`, and `## Relevant Plan Sections` headings.

## SKILL.md Changes

### Phase 2: Task schema documentation updated
- Document new optional fields: `fileContents`, `grillDecisions`, `planSections`

### Phase 3: Enrichment required
- Master MUST collect contextSummary, grillSummary, taskIntakeSnapshot before calling Phase 3
- Master MUST pass tasks array for contract validation

### Phase 4: Enrichment required  
- Master MUST Read all task.files before calling Phase 4
- Master MUST expand grillRefs keys into grillDecisions
- Master MUST build enriched task objects

## Success Criteria

1. `buildImplementerPrompt()` accepts new optional fields
2. Backward compatible when fields are absent
3. SKILL.md documents enrichment requirements for Phase 3 and Phase 4
4. `bash tests/test-*.sh` pass
5. `git diff --check` clean

## Risks

- Low risk: fileContents may increase token usage per sub-agent, but 1M context window makes this negligible
- Low risk: Master must spend time reading files before Phase 4, but this is a one-time cost per workflow run

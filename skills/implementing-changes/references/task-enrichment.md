# Task Enrichment Algorithm

## Purpose

Before dispatching tasks to the `phase4-implement` Workflow, the master agent must enrich each task with full context. Subagents start with blank context — they receive only what the master agent embeds in the enriched task.

## Enrichment Steps

For each task in the parsed `json:tasks` array:

### Step a: Read Target Files

Use `Read()` on every file listed in `task.files`. Build the `fileContents` array:

```json
"fileContents": [
  {"file": "internal/repository/store.go", "content": "<full file content>"},
  ...
]
```

Embed the COMPLETE file content, not summaries. Subagents have large context windows — token budget is not a constraint.

### Step b: Resolve Grill Decisions

Read `.claude/state/grill-evidence.json` if it exists (simple tasks may skip the Grill, so this file may be absent).

For each key in `task.grillRefs`:
- Match against `ambiguityRegister[].id` — extract the `decision` field.
- Match against `assumptionLedger[].id` — extract the `assumption`, `evidence`, and `confidence` fields.

Build the `grillDecisions` array:

```json
"grillDecisions": [
  {"key": "Q1-ConfigRouting", "decision": "Two MySQL configs: admin stays in yunui_mixyun..."},
  ...
]
```

If `grillRefs` is empty or grill-evidence.json is absent, leave `grillDecisions` as an empty array. Do not block enrichment.

### Step c: Extract Plan Sections

Read the approved plan file. For each task, extract the approach steps and verification sections that are relevant to this task's scope. Build the `planSections` string — a focused excerpt from the plan that applies to this specific task.

Do not embed the entire plan for every task. Each task gets only its relevant sections.

### Step d: Initialize diffText

The `diffText` field is initialized as empty during enrichment. It is populated later by the workflow script after implementation, for consumption by Phase 5 review.

The field name `diffText` is the canonical name for Phase 5 review diffs. Do not use `diff` as a separate field — `diffText` is the single source of truth for per-task git diffs flowing into review.

### Step e: Build Enriched Task Object

The final enriched task object contains all original fields plus:

```json
{
  "id": "T1-short-name",
  "prompt": "Self-contained implementation instruction...",
  "files": ["exact/path"],
  "complexity": "simple | medium | complex",
  "mutatesFiles": true,
  "contextRefs": [],
  "intakeRefs": [],
  "grillRefs": [],
  "expectedEvidence": ["evidence string 1", "evidence string 2"],
  "forbiddenEvidence": ["forbidden pattern 1"],
  "patchBackStrategy": "no-isolation | harness-managed | external-report",
  "fileContents": [{"file": "path", "content": "full content"}],
  "grillDecisions": [{"key": "Q1", "decision": "resolved decision"}],
  "planSections": "Relevant plan excerpt for this task...",
  "diffText": "",
  "expectedEvidenceText": "- evidence string 1\n- evidence string 2",
  "forbiddenEvidenceText": "- forbidden pattern 1"
}
```

## Evidence Normalization

Before passing tasks into prompt-oriented Workflow calls, normalize the evidence arrays into readable text strings:

```
expectedEvidenceText = task.expectedEvidence.map(e => `- ${e}`).join('\n')
forbiddenEvidenceText = task.forbiddenEvidence.map(e => `- ${e}`).join('\n')
```

**Critical rule:** The canonical arrays (`expectedEvidence` and `forbiddenEvidence`) MUST be preserved in the task object exactly as defined. The text fields (`expectedEvidenceText` and `forbiddenEvidenceText`) are derived display fields for prompt consumption only.

## Isolation Strategy Routing

The `patchBackStrategy` field determines how each task's changes flow back:

| Strategy | Behavior | Phase 4.5 Handling |
|----------|----------|--------------------|
| `no-isolation` | Agent works directly in the current tree | Changes are already in-tree; verify expectedEvidence |
| `harness-managed` | Worktree isolation with harness-managed lifecycle | Master reviews worktree diff, validates evidence, merges back |
| `external-report` | Manual integration | Flag as DONE_WITH_CONCERNS; document manual steps needed |

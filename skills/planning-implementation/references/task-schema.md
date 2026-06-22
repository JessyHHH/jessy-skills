# Task Schema

Each task in the `json:tasks` block of an implementation plan MUST include all required fields below. The schema is designed for Phase 4 Codex subagent execution. Subagents implementing tasks start with bounded context and rely on the task object plus injected file/context snippets for instructions.

## Required Fields

```json
{
  "id": "T1-short-name",
  "prompt": "Self-contained implementation instruction for a subagent starting with blank context.",
  "files": ["exact/path/to/file.go", "exact/path/to/another.go"],
  "complexity": "simple | medium | complex",
  "mutatesFiles": true,
  "contextRefs": [],
  "intakeRefs": [],
  "grillRefs": [],
  "expectedEvidence": [],
  "forbiddenEvidence": [],
  "patchBackStrategy": "no-isolation | harness-managed | external-report",
  "fileContents": [],
  "grillDecisions": [],
  "planSections": ""
}
```

## Field Descriptions

### `id` (string, required)

Unique task identifier. Format: `T<number>-<short-name>`. Example: `T1-create-store-interface`, `T2-implement-grpc-handler`.

### `prompt` (string, required)

Self-contained implementation instruction. The subagent starts with blank context -- this prompt is its sole source of instruction. Must include:
- What to implement
- Where to put it
- Any constraints or conventions to follow
- Expected behavior

### `files` (string[], required)

Exact file paths this task creates or modifies. Relative to the repository root. Used by the master agent to pre-read file contents for enrichment, and by the Quick Gate to verify expected changes.

### `complexity` (string, required)

Task complexity level. Drives subagent selection and review gating:
- `simple`: usually handled by main Codex or one executor; skips spec review.
- `medium`: use one bounded executor or reviewer as needed; runs spec review.
- `complex`: may use parallel read-only reviewers or disjoint writer subagents; runs full review.

### `mutatesFiles` (boolean, required)

Whether this task writes to the filesystem. Controls isolation strategy selection. Set `false` for read-only analysis or verification tasks.

### `contextRefs` (string[], optional)

References to Phase 0/0.3 context artifacts this task depends on. Used as fallback references when `fileContents` is not provided by the master agent during Phase 4 enrichment. Example: `["contextSummary.confirmedFacts", "knowledgePath"]`.

### `intakeRefs` (string[], optional)

References to Phase 0 Task Intake Snapshot entries relevant to this task. Example: `["taskIntake.approvedInScope", "taskIntake.constraints"]`.

### `grillRefs` (string[], optional)

References to Phase 1 Ambiguity Register or Assumption Ledger entries relevant to this task. Used as fallback references when `grillDecisions` is not provided. Example: `["A1-ConfigRouting", "S1-DatabaseSchema"]`. The main Codex session resolves these against `.codex/state/grill-evidence.json` during Phase 4 enrichment.

### `expectedEvidence` (string[], required)

Specific evidence expected upon completion. Examples:
- `"go build ./... exits 0"`
- `"TestCreateUser passes"`
- `"golangci-lint run ./... shows 0 new warnings"`
- `"new file internal/store/user.go exists"`

### `forbiddenEvidence` (string[], required)

Evidence that MUST NOT appear after implementation. Examples:
- `"no new TODO comments in production code"`
- `"no import cycles"`
- `"no os.Getenv in library code"`

### `patchBackStrategy` (string, required for mutating tasks)

How changes flow back to the master tree:

- `no-isolation`: Agent works directly in the current tree. Use for simple, low-risk tasks. Changes are immediately visible.
- `harness-managed`: Worktree isolation with harness-managed lifecycle. Phase 4.5 master agent reviews worktree diffs and merges back approved changes.
- `external-report`: Manual integration. Task marked `DONE_WITH_CONCERNS` and requires human intervention.

### `fileContents` (object[], optional, filled by master agent)

Full file contents for embedding in the sub-agent prompt. The master agent fills this before Phase 4 by reading each file in `task.files`. Each entry: `{file: "path/to/file.go", content: "<full file content>"}`.

### `grillDecisions` (object[], optional, filled by master agent)

Resolved grill decisions by key. The main Codex session fills this from `.codex/state/grill-evidence.json` before Phase 4. Each entry: `{key: "A1-ConfigRouting", decision: "Two MySQL configs: admin stays in yunui_mixyun..."}`.

Resolution logic: match `grillRefs` keys against `ambiguityRegister[].id` or `assumptionLedger[].id` in grill-evidence.json. Extract the `decision` field (for register entries) or `assumption`+`evidence`+`confidence` fields (for ledger entries).

### `planSections` (string, optional, filled by master agent)

Relevant plan sections extracted from the implementation plan. The master agent extracts approach steps and verification sections relevant to this task's scope before Phase 4. Injected into the sub-agent prompt under a dedicated heading.

## Validation Rules

1. Every task MUST have a unique `id`.
2. Every `id` MUST match the pattern `T<number>-<short-name>`.
3. Every `prompt` MUST be self-contained (no "see above" or "as discussed").
4. Every mutating task (`mutatesFiles: true`) MUST have a `patchBackStrategy`.
5. Every task MUST have at least one `expectedEvidence` entry or a documented verification approach.
6. `files` paths MUST be exact (relative to repo root, no globs).
7. `complexity` MUST be one of: `simple`, `medium`, `complex`.
8. `patchBackStrategy` MUST be one of: `no-isolation`, `harness-managed`, `external-report`.

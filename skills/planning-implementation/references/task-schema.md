# Phase 4 Task Schema

Every object in a plan's `json:tasks` block defines one atomic deliverable. Phase 4 validates the block with `skills/implementing-changes/scripts/phase4_guard.py` before dispatch.

## Required Shape

```json
{
  "id": "T1-short-name",
  "prompt": "Self-contained atomic outcome for task-local context.",
  "files": ["exact/allowed/write.go"],
  "readFiles": ["exact/input/interface.go"],
  "resources": ["db:test-users"],
  "dependsOn": [],
  "complexity": "simple | medium | complex",
  "mutatesFiles": true,
  "contextRefs": [],
  "intakeRefs": [],
  "grillRefs": [],
  "acceptanceCommands": ["go test ./internal/user"],
  "expectedEvidence": [],
  "forbiddenEvidence": [],
  "patchBackStrategy": "harness-managed"
}
```

## Boundary Fields

### `id`

Use a unique `T<number>-<short-name>` identifier.

### `prompt`

Describe one independently reviewable outcome, its required behavior, and relevant conventions. Do not combine unrelated deliverables or refer to missing conversation context.

### `files`

List every file the task may create, modify, rename, or delete. Paths are exact and repository-relative; globs and directory-wide ownership are invalid. This array is the mechanical write allowlist. A writer must stop with `BOUNDARY_BLOCKED` before touching anything else.

### `readFiles`

List known repository files whose contents affect the task even when they are not writable. Read/write intersections prevent unsafe concurrency.

### `resources`

List shared non-file state such as `db:test-users`, `service:docker-compose`, `port:8080`, `cache:go-build`, or `generated:go.sum`. Tasks sharing a resource run serially. Use `unknown` when resource ownership cannot be bounded; it conflicts with every task.

### `dependsOn`

List task IDs whose accepted integration must exist before this task starts. Dependencies must exist, cannot reference the task itself, and must form an acyclic graph.

## Evidence Fields

### `acceptanceCommands`

Provide at least one concrete command that can be inspected and executed inside the task worktree. Commands are evidence contracts, not automatically trusted shell input; the main session reviews them before execution.

### `expectedEvidence`

List observable completion facts, such as a named test passing or a new file existing. Do not use subjective phrases such as "looks correct".

### `forbiddenEvidence`

List explicit non-goals and prohibited results, including forbidden dependencies, APIs, files, migrations, or external state changes.

## Execution Fields

### `complexity`

- `simple`: narrow local behavior.
- `medium`: multiple related edits or meaningful compatibility concerns.
- `complex`: cross-module contracts, migrations, or high-risk behavior.

Complexity affects review depth, not task boundaries.

### `mutatesFiles`

Set `true` for writer tasks. Read-only tasks must have an empty `files` array.

### `patchBackStrategy`

- `harness-managed`: required for writer subagents. Use an isolated linked worktree and main-session integration.
- `no-isolation`: allowed only for main-session implementation or a recorded escape hatch. Never run concurrently.
- `external-report`: no automatic integration; requires manual handling.

## Context References

`contextRefs`, `intakeRefs`, and `grillRefs` identify task-local facts that the main session resolves before dispatch. Do not pass the entire parent conversation. The main session may also inject fresh `fileContents`, resolved `grillDecisions`, and relevant `planSections`; these are enrichment outputs, not canonical plan requirements.

## Concurrency Rule

Tasks may share one execution wave only when all conditions hold:

```text
W1 intersects (R2 union W2) = empty
W2 intersects (R1 union W1) = empty
resources do not overlap
neither task depends on the other
both writers use separate harness-managed worktrees
```

Default to one writer. Cap writer concurrency at two. Run integration serially.

## Validation

Run:

```bash
python3 skills/implementing-changes/scripts/phase4_guard.py validate-plan <plan>
python3 skills/implementing-changes/scripts/phase4_guard.py schedule <plan>
```

Do not approve a plan that fails either command.

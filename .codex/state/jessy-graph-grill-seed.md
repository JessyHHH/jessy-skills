# Jessy Graph Architecture Grill Seed

## Requirement Echo

We will create a new project named `jessy-graph` at
`/root/hzx_mixlinker/jessy-graph`. It will use LangGraph as the durable
orchestration runtime around Codex CLI workers. `jessy-skills` remains the
policy, role, prompt, and versioned task-contract layer.

The first architecture specification must define a two-level graph:

- a project graph for planning approval, task-DAG scheduling, serial
  integration, combined verification, and final approval;
- a task-execution subgraph for worktree preparation, Codex execution, scope
  validation, fixed checks, review, retry, and artifact generation.

The runtime must treat Git and deterministic validators as evidence sources,
must not trust worker self-reports, and must persist project, task, attempt,
artifact, and approval records.

## Success Direction

- A run can pause for approval, survive process restart, and resume by stable
  ID without repeating completed external effects.
- Every worker uses an isolated worktree at an immutable base commit.
- Exact file and shared-resource boundaries are enforced from the existing
  jessy-skills task contract.
- New, deleted, renamed, binary, symlink, and submodule changes are detected.
- Fixed verification commands run independently from the Codex worker.
- Integration is serial and produces a reviewable patch or integration branch;
  no automatic push or deployment is allowed in the first release.
- Events, diffs, logs, and patches are immutable artifacts referenced by hash;
  large payloads are not copied into LangGraph checkpoints.
- Restart, retry, timeout, cancellation, boundary violation, and dirty target
  workspace behaviors have automated tests.

## Open Decisions

1. Choice: local single-user trusted workstation service or remote multi-user
   service for the first release?
2. Choice: SQLite persistence first or PostgreSQL from the first release?
3. Choice: host Codex sandbox plus dedicated Unix user or containerized worker
   isolation for the first release?
4. Choice: patch-only handoff or a dedicated integration worktree and branch?
5. Choice: single-task vertical slice first or enable project DAG scheduling in
   the first implementation milestone?
6. Choice: local CLI first or MCP server in the first implementation milestone?
7. Open question: which repository languages and verification command families
   are supported in the first release?
8. Trade-off: how much automatic retry is allowed before human review?
9. Dependency: concurrency limits depend on worker isolation and persistence.
10. Dependency: MCP and remote access depend on the first-release trust model.

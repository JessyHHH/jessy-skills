# Phase 4 Controlled Worktree Execution

## Goal

Prevent Phase 4 writer subagents from drifting outside an approved atomic task while preserving safe parallelism for genuinely independent work.

## Decisions

- Dispatch one atomic task per writer subagent.
- Treat `files` as the exact writable allowlist.
- Require explicit forbidden evidence and executable acceptance commands.
- Use a two-turn protocol: the subagent returns a plan without editing, then waits for `APPROVE_EXECUTION <task-id>`.
- Require task-local context and prohibit recursive delegation.
- Stop with `BOUNDARY_BLOCKED` instead of expanding scope.
- Require status, diff, commands, evidence, and risks in the execution result.
- Use one linked Git worktree and branch per writer task.
- Default writers to serial execution. Permit at most two concurrent writers only when dependencies, read/write sets, resources, and worktrees are independent.
- Keep integration serial in the main Codex session.
- Enforce task schema, scheduling, and changed-file boundaries with a deterministic helper.

## Non-Goals

- Build a general-purpose task runner.
- Automatically execute arbitrary acceptance commands from plan files.
- Automatically commit, cherry-pick, delete branches, or force-remove worktrees.
- Treat worktrees as isolation for databases, services, ports, caches, or user files.

## Success Criteria

- Invalid Phase 4 task contracts fail before dispatch.
- Dependency, file, and shared-resource conflicts produce serial schedule waves.
- Independent tasks may share a wave, capped at two writers.
- A changed file outside the task allowlist makes the scope gate fail.
- Phase 4 instructions require plan approval before edits and full diff evidence afterward.
- Changed skills validate and repository shell tests pass.
